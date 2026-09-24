library(tidyverse)
library(readxl)
library(here)

# source data path
input_file <- here("data", "01_raw", "SourceData.xlsx")
output_dir <- here("data", "02_output")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
check <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)
number <- function(x, context) {
  y <- suppressWarnings(as.numeric(x))
  check(all(is.finite(y)), paste("Invalid number in", context))
  y
}
strict_source_checks <- TRUE

# load data
evt <- read_excel(input_file, sheet = "Notes") %>% rename(region = Region, latitude = Latitude, longitude = Longitude)
tm <- read_excel(input_file, sheet = "TraceMetals") 
mm <- read_excel(input_file, sheet = "Morphometrics") %>%
  rename(krill_id = `Krill ID`, length_mm = `Length (mm)`, sex_stage = `Sex/Stage`, site = Site)
mm <- mm %>% mutate(source_row = row_number() + 1L,
                    length_raw = as.character(length_mm),
                    stage_raw = sex_stage, stage = na_if(sex_stage, "--"))
isotopes <- read_excel(input_file, sheet = "StableIsotopes") %>%
  rename(krill_id = `Krill ID`, site = Site) %>%
  mutate(source_row = row_number() + 1L) %>%
  group_by(krill_id) %>% mutate(source_repeat = row_number(), repeat_count = n()) %>% ungroup()
metals <- tm %>% rename(element = Element) %>%
  mutate(source_row = row_number() + 1L) %>%
  mutate(across(starts_with("K"), as.character)) %>%
  pivot_longer(starts_with("K"), names_to = "krill_id", values_to = "value")
check(!anyDuplicated(mm$krill_id), "Duplicate specimen IDs")
check(all(isotopes$krill_id %in% mm$krill_id), "Unknown isotope specimen")
check(all(metals$krill_id %in% mm$krill_id), "Unknown metal specimen")
check(all(isotopes$site == mm$site[match(isotopes$krill_id, mm$krill_id)]), "Conflicting sites")

# Manually transcribed metadata from Supplementary Methods, p.1.
# Edit eventDate here if exact collection dates become available.
# use "region" as column name so that it's the same name as evt for join later
site_metadata <- tribble(
  ~region,             ~dive,   ~eventDate,               ~habitat,                       ~minimumDepthInMeters, ~maximumDepthInMeters, ~higherGeographyID,
  "Antarctic Sound", "S0767", "2024-12-21/22", "Non-vent-associated marine site", 270, 290, "https://www.wikidata.org/wiki/Q571127",
  "Hook Ridge",      "S0770", "2024-12-26/27", "Marine hydrothermal vent site",   1020, 1160, NA 
)


# Source DMS example: 62 degrees 11 minutes 51 seconds S.
dms_to_dd <- function(x, axis) {
  parts <- str_match(x, "^([0-9]+)°([0-9]+)'([0-9]+(?:\\.[0-9]+)?)''([NSEW])$")
  deg <- as.double(parts[, 2]); min <- as.double(parts[, 3])
  sec <- as.double(parts[, 4]); hemi <- parts[, 5]
  allowed <- if (axis == "latitude") c("N", "S") else c("E", "W")
  value <- (deg + min / 60 + sec / 3600) * if_else(hemi %in% c("S", "W"), -1, 1)
  limit <- if (axis == "latitude") 90 else 180
  round(value, digits = 4)
}


# Event core
doi <- "https://doi.org/10.1038/s42003-026-10780-1"
cruise_doi <- "https://doi.org/10.7284/910878"

event <- site_metadata %>%
  left_join(evt, by = "region") %>%
  transmute(
    eventID = paste("FKt241214", dive, sep = "_"),
    parentEventID = cruise_doi,
    fieldNumber = dive,
    eventDate,
    samplingProtocol = "ROV SuBastian suction sampler aboard R/V Falkor (too). The ROV lights were turned on for the descent of both dives and descent rates averaged 0.34 m
s-1 and 0.29 m s-1 for S0770 and S0767, respectively. ROV SuBastian, depth-rated to 4,500 m,
was equipped with a UHD pan-zoom-tilt science camera (SULIS Z70, 4K resolution) and four
auxiliary HD SeaCams. A Sea-Bird FastCAT SBE-49 CTD and an SBE-3 thermistor (recording
at 1 Hz, ±0.002 °C accuracy) were mounted 0.5 m above the skid. A high-temperature PT-100
probe capable of measuring from 0–600 °C was mounted on the starboard manipulator.
Navigation was provided by a Sonardyne Sprint-INS, Syrinx DVL, and USBL positioning
system. Sampling tools included a five-chamber suction sampler (4 L min⁻¹), two 2-L Niskin
bottles, push-cores, and an insulated “biobox”. Illumination was provided by twin 150 W LEDs;
total lamp irradiance at 1.0 m was < 10⁻⁷ W m⁻². Vehicle dimensions 2.7 × 2.2 × 1.8 m; weight in
air 3 200 kg; top speed 3 kn (schmidtocean.org). Krill were collected during FKt241214 with the ROV SuBastian suction sampler on each dive
and held in 1-L sample chambers until the ROV was back on deck. Extracted from supplementary material at https://doi.org/10.1038/s42003-026-10780-1 ",
    locality = region,
    waterBody = "Southern Ocean",
    habitat,
    verbatimLatitude = latitude, verbatimLongitude = longitude,
    verbatimCoordinateSystem = "degrees minutes seconds",
    geodeticDatum = "EPSG:4326",
    georeferenceSources = "SourceData.xlsx, Notes sheet",
    georeferenceRemarks = paste("Site coordinates converted from DMS.",
                                "Datum and positional uncertainty not reported."),
    eventRemarks = paste0(
      "Expedition FKt241214; Rolling Deck to Repository cruise record: ", cruise_doi, "; dive ", dive, ". ",
      "eventDate records the updated dive date range ", eventDate, ". ",
      "One event represents the sampled individuals from this dive; finer collection times are unavailable. ",
      "Individual capture depths are not assigned. Sampling context: ", doi, "; Supplementary Methods p.1."
    ),
    decimalLatitude = dms_to_dd(latitude, "latitude"),
    decimalLongitude = dms_to_dd(longitude, "longitude"),
  ) %>%
  mutate(across(where(is.character), str_squish))

cruise_event <- tibble(
  eventID = cruise_doi,
  parentEventID = NA_character_,
  fieldNumber = "FKt241214",
  eventDate = "2024-12-15/2025-01-03",
  waterBody = "Southern Ocean",
  eventRemarks = paste(
    "Parent expedition FKt241214 aboard R/V Falkor (too).",
    "Cruise identifier and Rolling Deck to Repository record:", cruise_doi,
    "; expedition interval from Supplementary Methods p.1 of", doi,
    ". Child events represent the Antarctic Sound and Hook Ridge sampling dives."
  )
)
event <- bind_rows(cruise_event, event)

specimens <- mm %>%
  left_join(event %>% select(site = locality, eventID), by = "site") %>%
  mutate(occurrenceID = paste(eventID, krill_id, sep = "_"))

# 4. Occurrence extension ---------------------------------------------------
occurrence <- specimens %>%
  transmute(
    eventID, occurrenceID,
    # The material was collected, dissected and dried
    basisOfRecord = "MaterialSample",
    occurrenceStatus = "detected",
    individualCount = 1L,
    organismID = occurrenceID,
    scientificName = "Euphausia superba",
    scientificNameAuthorship = "Dana, 1850",
    scientificNameID = "urn:lsid:marinespecies.org:taxname:236217",
    kingdom = "Animalia", taxonRank = "species",
    sex = case_when(str_starts(stage, "M") ~ "male",
                    str_starts(stage, "F") ~ "female",
                    TRUE ~ NA_character_),
    lifeStage = if_else(stage == "J", "juvenile", NA_character_),
    reproductiveCondition = if_else(stage == "F3D", "gravid", NA_character_),
    associatedReferences = doi,
    occurrenceRemarks = paste0(
      "Source krill ID: ", krill_id, "; verbatim Sex/Stage: ", coalesce(stage_raw, "[blank]"),
      ". SourceData.xlsx, Morphometrics row ", source_row,
      ". M=male; F=female; J=juvenile (Table S1). -- treated as missing. ",
      "Stage codes retained in eMoF; other maturity suffixes not expanded. ",
      "individualCount represents this specimen, not total abundance at the site."
    )
  )

# 5. eMoF: morphology, isotope replicates and elemental concentrations -------
# P01 terms verified against NVS definitions; see references/p01-mappings.md.
isotope_dictionary <- tribble(
  ~parameter, ~key,   ~measurementType,                       ~measurementUnit,
  "%C",      "pctC", "Carbon mass fraction in krill tissue", "%",
  "δ13C",    "d13C", "Carbon stable isotope delta 13C",      "per mil",
  "%N",      "pctN", "Nitrogen mass fraction in krill tissue", "%",
  "δ15N",    "d15N", "Nitrogen stable isotope delta 15N",    "per mil"
) %>% mutate(
  measurementTypeID = paste0("http://vocab.nerc.ac.uk/collection/P01/current/",
                             c("CBDYXX01", "C13BTX01", "NTDYXX01", "N15BTX01"), "/"),
  measurementUnitID = paste0("http://vocab.nerc.ac.uk/collection/P06/current/",
                             c("UPCT", "UPPT", "UPCT", "UPPT"), "/")
)

length_emof <- specimens %>%
  filter(!is.na(length_raw)) %>%
  transmute(
    eventID, occurrenceID,
    measurementID = paste0(occurrenceID, ":length"),
    verbatimMeasurementType = "Total body length", measurementValue = length_raw,
    measurementType = "Length (total length) of biological entity specified elsewhere",
    measurementTypeID = "http://vocab.nerc.ac.uk/collection/P01/current/TL01XX01/",
    measurementUnit = "mm",
    measurementUnitID = "http://vocab.nerc.ac.uk/collection/P06/current/UXMM/",
    measurementMethod = "Tip of rostrum to end of uropods; Standard Length 1 (Supplementary Methods p.1).",
    measurementRemarks = paste0("SourceData.xlsx; Morphometrics; row ", source_row, "; Length (mm).")
  )

stage_emof <- specimens %>%
  filter(!is.na(stage)) %>%
  transmute(
    eventID, occurrenceID,
    measurementID = paste0(occurrenceID, ":sex-stage"),
    measurementType = "Sex and maturity stage code", measurementValue = stage,
    measurementTypeID = "http://vocab.nerc.ac.uk/collection/P01/current/LSTAGE01/",
    measurementUnit = NA_character_,
    measurementUnitID = "http://vocab.nerc.ac.uk/collection/P06/current/XXXX/",
    measurementMethod = "Makarov and Denys (1980) staging, as stated in Supplementary Methods and Table S1.",
    measurementRemarks = paste0("SourceData.xlsx; Morphometrics; row ", source_row,
                                "; Sex/Stage; original sex-specific developmental stage code retained. ",
                                "P01 describes development stage; sex is also provided in the occurrence extension.")
  )

isotope_emof <- isotopes %>%
  pivot_longer(all_of(isotope_dictionary$parameter), names_to = "parameter", values_to = "value") %>%
  filter(!is.na(value)) %>%
  mutate(numeric_value = number(value, "StableIsotopes")) %>%
  left_join(isotope_dictionary, by = "parameter") %>%
  left_join(specimens %>% select(krill_id, eventID, occurrenceID), by = "krill_id") %>%
  transmute(
    eventID, occurrenceID,
    measurementID = paste(occurrenceID, "isotope", paste0("row", source_row), key, sep = ":"),
    measurementType, measurementTypeID, measurementValue = as.character(value), measurementUnit,
    measurementUnitID,
    measurementMethod = paste(
      "Elemental analysis/continuous-flow isotope-ratio mass spectrometry; dried, ground bulk krill tissue;",
      "Thermo-Scientific Flash EA IsoLink / Delta-Q; Oregon State Stable Isotope Collaboratory.",
      "Delta 13C reference VPDB; delta 15N reference air (Supplementary Methods p.2)."
    ),
    measurementRemarks = paste0(
      "SourceData.xlsx; StableIsotopes; row ", source_row, "; ", parameter,
      "; source repeat ", source_repeat, " of ", repeat_count,
      " for this krill. Repeat index assigned from source row order, not a laboratory replicate ID. ",
      "Reported value retained without averaging or additional lipid correction. ",
      if_else(parameter == "δ13C", "Correction status of exported delta 13C is not explicit in Table S5.", "")
    )
  )

element_dictionary <- tribble(
  ~element, ~element_name,
  "As", "Arsenic", "Ba", "Barium", "Cd", "Cadmium", "Co", "Cobalt",
  "Cr", "Chromium", "Cu", "Copper", "Fe", "Iron", "Mn", "Manganese",
  "Mo", "Molybdenum", "Ni", "Nickel", "P", "Phosphorus", "Pb", "Lead",
  "V", "Vanadium", "Zn", "Zinc"
)
check(all(metals$element %in% element_dictionary$element), "Unmapped element.")
metal_numbers <- number(metals$value[!is.na(metals$value) & metals$value != "<LOD"], "TraceMetals")
check(all(metal_numbers >= 0), "Negative elemental concentration.")

metal_emof <- metals %>%
  filter(!is.na(value)) %>%
  left_join(element_dictionary, by = "element") %>%
  left_join(specimens %>% select(krill_id, eventID, occurrenceID), by = "krill_id") %>%
  transmute(
    eventID, occurrenceID,
    measurementID = paste(occurrenceID, "element", element, sep = ":"),
    measurementType = paste(element_name, "concentration in dried krill tissue"),
    measurementValue = value,
    measurementUnit = "mg/kg",
    measurementMethod = paste(
      "Dried, ground krill tissue; nitric acid/hydrogen peroxide digestion; HR-ICP-MS",
      "(Element2 ThermoFisher); reagent and digestion blank correction.",
      "Concentration as reported in Table S3; no phosphorus normalization applied by this script."
    ),
    measurementRemarks = paste0(
      "SourceData.xlsx; TraceMetals; row ", source_row, "; column ", krill_id,
      "; element ", element, ". Units from Table S3; dry-tissue preparation from Methods. ",
      "P01 mapping unresolved: no suitable krill/generic-biota dry-weight term verified. ",
      if_else(value == "<LOD",
              "Below detection limit; retained verbatim. Sample-specific tissue LOD not assigned from reference-mass LODs. ", ""),
      if_else(krill_id == "K038" & element %in% c("P", "Zn"),
              "Above upper range of standard curve (red entry in Table S3); retain with caution.", "")
    )
  )

# Published environmental summaries belong to the dive, not an individual krill.
temperature_emof <- tribble(
  ~locality, ~key, ~measurementType, ~measurementValue, ~context,
  "Antarctic Sound", "bottom-mean", "Mean bottom water temperature", "-1.35", "Mean bottom temperature at the survey site.",
  "Hook Ridge", "bottom-mean", "Mean bottom water temperature", "-1.21", "Mean bottom temperature at the survey site.",
  "Hook Ridge", "near-vent-maximum", "Maximum near-vent water temperature", "1.38", "Maximum within approximately 2 m of the vent where krill were collected.",
  "Hook Ridge", "vent-fluid", "Hydrothermal vent fluid temperature", ">200", "Vent fluid exceeded 200 degrees Celsius; lower bound retained, not an exact value or krill exposure temperature."
) %>%
  left_join(event %>% select(locality, eventID), by = "locality") %>%
  transmute(
    eventID, occurrenceID = NA_character_,
    measurementID = paste(eventID, "temperature", key, sep = ":"),
    measurementType,
    measurementTypeID = if_else(key == "vent-fluid", NA_character_,
      "http://vocab.nerc.ac.uk/collection/P01/current/TEMPPR01/"),
    measurementValue, measurementUnit = "degrees Celsius",
    measurementUnitID = "http://vocab.nerc.ac.uk/collection/P06/current/UPAA/",
    measurementMethod = paste(
      "Published ROV survey summary. Supplementary Methods p.1 describes a Sea-Bird FastCAT SBE-49 CTD",
      "and SBE-3 thermistor (1 Hz, +/-0.002 degrees Celsius) mounted 0.5 m above the skid,",
      "and a PT-100 high-temperature probe (0-600 degrees Celsius) on the starboard manipulator.",
      "Individual summary-to-sensor attribution and summary uncertainty are not specified."
    ),
    measurementRemarks = paste("Source:", doi, "p.2, Results: Survey site observations.", context,
      "Event-level environmental observation; occurrenceID intentionally empty.")
  )

emof <- bind_rows(length_emof, stage_emof, isotope_emof, metal_emof, temperature_emof) %>%
  mutate(measurementValueID = NA_character_, measurementAccuracy = NA_character_) %>%
  select(eventID, occurrenceID, measurementID, measurementType, measurementTypeID,
         measurementValue, measurementValueID, measurementUnit, measurementUnitID,
         measurementAccuracy, measurementMethod, measurementRemarks) %>%
  arrange(eventID, occurrenceID, measurementID)

check(sum(!is.na(emof$measurementTypeID)) == 212L, "Expected 212 P01-mapped measurements.")
check(all(is.na(emof$measurementTypeID) == str_detect(emof$measurementID, ":element:|:temperature:vent-fluid$")),
      "Only trace-element and vent-fluid P01 mappings should be unresolved.")

# 6. Validation and export --------------------------------------------------
check(!anyNA(event$eventID) && !anyDuplicated(event$eventID), "Invalid event IDs.")
check(all(na.omit(event$parentEventID) %in% event$eventID), "Parent event missing from Event core.")
check(all(is.na(event$parentEventID) | event$parentEventID != event$eventID), "Self-referencing parent event.")
check(sum(is.na(event$parentEventID)) == 1L &&
        event$eventID[is.na(event$parentEventID)] == cruise_doi,
      "Expected the cruise as the single root event.")
check(!anyNA(occurrence$occurrenceID) && !anyDuplicated(occurrence$occurrenceID), "Invalid occurrence IDs.")
check(!anyNA(emof$measurementID) && !anyDuplicated(emof$measurementID), "Invalid measurement IDs.")
check(nrow(anti_join(occurrence, event, by = "eventID")) == 0, "Orphan occurrence.")
check(nrow(anti_join(emof, event, by = "eventID")) == 0, "Orphan measurement event.")
check(nrow(anti_join(filter(emof, !is.na(occurrenceID)), occurrence,
                    by = c("eventID", "occurrenceID"))) == 0, "Orphan or mismatched specimen measurement.")
check(all(is.na(emof$occurrenceID) == str_detect(emof$measurementID, ":temperature:")),
      "Only environmental temperatures should have empty occurrenceID.")
check(!anyNA(emof$measurementValue) && !anyNA(emof$measurementType), "Empty measurement.")
check(all(event$eventDate[match(site_metadata$dive, event$fieldNumber)] == site_metadata$eventDate),
      "Dive event dates do not match the configured site metadata.")

if (strict_source_checks) {
  check(nrow(event) == 3L && nrow(occurrence) == 39L, "Unexpected event/occurrence count.")
  check(nrow(isotopes) == 33L && n_distinct(isotopes$krill_id) == 28L, "Unexpected isotope coverage.")
  check(nrow(metals) == 112L, "Unexpected elemental measurement count.")
  check(nrow(emof) == 325L && nrow(temperature_emof) == 4L,
        "Expected 321 specimen measurements + 4 environmental temperatures.")
  check(sum(emof$measurementValue == "<LOD") == 1L, "Expected one censored metal value.")
}

# Coverage makes absent assays visible; do not create measurements for them.
coverage <- specimens %>%
  select(krill_id, site, occurrenceID) %>%
  left_join(isotopes %>% count(krill_id, name = "isotope_source_rows"), by = "krill_id") %>%
  left_join(metals %>% filter(!is.na(value)) %>% count(krill_id, name = "metal_values"), by = "krill_id") %>%
  mutate(across(c(isotope_source_rows, metal_values), ~ replace_na(.x, 0L)))

event_export <- event %>%
  mutate(across(c(decimalLatitude, decimalLongitude),
                ~ if_else(is.na(.x), NA_character_, sprintf("%.4f", .x))))
write_tsv(event_export, file.path(output_dir, "event.txt"), na = "", quote = "needed")
event_lines <- read_lines(file.path(output_dir, "event.txt"))
check(length(event_lines) == nrow(event) + 1L &&
        all(str_count(event_lines, fixed("\t")) == ncol(event) - 1L),
      "Event TSV must have one physical line per record and consistent tab-delimited columns.")
write_tsv(occurrence, file.path(output_dir, "occurrence.txt"), na = "")
write_tsv(emof, file.path(output_dir, "emof.txt"), na = "")
write_tsv(coverage, file.path(output_dir, "assay_coverage.txt"), na = "")

review_notes <- c(
  paste("Source workbook MD5:", unname(tools::md5sum(input_file))),
  paste("Source publication:", doi),
  paste("Parent cruise eventDate:", cruise_event$eventDate, "(expedition interval from Supplementary Methods p.1)."),
  paste0("Updated dive eventDate: ", site_metadata$dive, " (", site_metadata$region,
         ") = ", site_metadata$eventDate, ". These are dive date ranges, not individual collection times."),
  "Event remarks describe the updated dive date ranges; individual specimen collection times remain unavailable.",
  "Dive geodeticDatum is EPSG:4326; positional uncertainty is empty. Georeference remarks still state that the datum was not reported; datum attribution needs confirmation.",
  "P01 IDs assigned to 212 measurements; 112 trace-element IDs and one vent-fluid temperature ID remain unresolved. See references/p01-mappings.md.",
  "Four event-level temperature records transcribed from the paper p.2: Antarctic Sound mean bottom -1.35 C; Hook Ridge mean bottom -1.21 C, near-vent maximum 1.38 C, vent fluid >200 C. Empty occurrenceID denotes environmental context, not individual exposure.",
  paste("Event parentEventID links both dives to cruise FKt241214 at", cruise_doi),
  "The cruise is included as the root Event record with an empty parentEventID; all parent links resolve within the Event core.",
  "Event text whitespace is flattened for one-line-per-record UTF-8 tab-delimited import.",
  "decimalLatitude and decimalLongitude are exported with exactly four decimal places; missing coordinates are empty.",
  "No specimen capture depths assigned from survey bottom-depth ranges.",
  "K026 Sex/Stage is --; sex and lifeStage are blank; the source code is preserved in remarks.",
  "StableIsotopes contains 33 rows for 28 individuals, including only 24 Antarctic Sound individuals.",
  "Supplementary Methods says all 35 Antarctic Sound individuals were used for isotopes; the workbook does not supply all of those results.",
  "Repeated isotope values are retained as separate measurements with source-row identifiers.",
  "Delta 13C correction status is not explicit in Table S5; values are exported unchanged.",
  "K039 Ni is <LOD; K038 P and Zn are flagged above the calibration range in Table S3.",
  "Trace-metal reference LODs for 50/100 mg are not individual sample-specific tissue LODs.",
  "Quest Caldera observations and microbial sequence data are outside this workbook and are not added.",
  "Outputs are standalone TSV tables; see README for publication metadata limitations."
)
write_lines(review_notes, file.path(output_dir, "review_notes.txt"))
capture.output(sessionInfo(), file = file.path(output_dir, "sessionInfo.txt"))

write_lines(c("PASS: unique Event, Occurrence and Measurement identifiers",
              "PASS: all parentEventID links resolve within the Event core; cruise is the single root",
              paste0("PASS: dive eventDate matches configured site metadata: ",
                     paste(paste(site_metadata$dive, site_metadata$eventDate), collapse = "; ")),
              "NOTE: date checks confirm configured values, not independent verification of collection dates or times.",
              "NOTE: georeference remarks conflict with EPSG:4326.",
              "PASS: all occurrences reference an Event",
              "PASS: all measurements reference Events; specimen measurements reference matching Event/Occurrence pairs",
              "PASS: 3 events (1 cruise + 2 dives); 39 occurrences; 325 measurements (321 specimen + 4 environmental temperatures)",
              "PASS: Event TSV has one physical line per record and consistent tab counts",
              "PASS: isotope repeats retained; one <LOD retained",
              "PASS: 212 P01 mappings; 112 trace-element records and one vent-fluid temperature unmapped"),
            file.path(output_dir, "validation.txt"))

print(tibble(table = c("event", "occurrence", "emof"),
             rows = c(nrow(event), nrow(occurrence), nrow(emof))))
message("Saved UTF-8 TSV tables and review information to: ", output_dir)
