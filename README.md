[![DOI](https://zenodo.org/badge/1385135898.svg)](https://doi.org/10.5281/zenodo.22939289)

# Hydrothermal vent krills — Darwin Core

## Reproduce

Open `hydrothermal-vent-krills-dwc.Rproj` in RStudio, then:

```r
renv::restore()
source("src/transform-data.R")
```

Or run `Rscript src/transform-data.R` from the project root after restoring.
`renv.lock` records R 4.5.3 and the package dependency versions.
`renv/activate.R` and `.Rprofile` activate the project library automatically.

## Project directory

Top-level layout (`tree -L 1`; hidden files are omitted):

```text
.
|-- DESCRIPTION
|-- Makefile
|-- README.md
|-- data
|-- hydrothermal-vent-krills-dwc.Rproj
|-- references
|-- renv
|-- renv.lock
`-- src
```

- `DESCRIPTION`: project name, version, description and R package dependencies.
- `Makefile`: shortcuts to regenerate the data (`make data`), restore dependencies
  (`make restore`) and inspect the R environment (`make status`).
- `README.md`: reproduction instructions, data structure and interpretation notes.
- `data/`: the source workbook in `01_raw/` and generated TSV tables, review notes,
  validation results and R session information in `02_output/`.
- `hydrothermal-vent-krills-dwc.Rproj`: RStudio project settings; open this file to
  work with the project in RStudio.
- `references/`: the source paper, supplementary methods and tables, and documented
  NERC P01 vocabulary mappings.
- `renv/`: R environment activation code, settings and the local package library
  managed by renv.
- `renv.lock`: the recorded R and package versions used to restore the environment.
- `src/`: the R script that transforms source data, validates records and writes
  the Darwin Core TSV tables and supporting reports.

## Data and processing files

- `data/01_raw/SourceData.xlsx`: unchanged copy of the supplied workbook.
- `src/transform-data.R`: workbook mapping, joins, checks and TSV export.
- `data/02_output/event.txt`: 3 events: one parent cruise and two sampling dives/sites.
- `data/02_output/occurrence.txt`: 39 individually identified krill.
- `data/02_output/emof.txt`: 325 measurements/facts.
- `data/02_output/assay_coverage.txt`: assay coverage per individual.
- `data/02_output/review_notes.txt`: source limitations and decisions.
- `data/02_output/validation.txt`: conversion checks.
- `references/`: supplied paper and supplementary methods/tables.

Tables are UTF-8, tab-delimited text with a header. Event text has no embedded
line breaks or tabs, so each event occupies one physical line. In Numbers,
open `event.txt` and select **Tab** in the import delimiter settings if needed.

Both extensions link to Event through eventID. eMoF carries occurrenceID
for individual measurements; it is empty for event-level temperatures. Measurements comprise
39 lengths, 38 sex/stage codes, 132 isotope/composition values, and 112
elemental concentrations, plus 4 environmental temperatures. Repeated isotope analyses retain source-row IDs;
values are not averaged. `<LOD` is retained as text. Missing stage `--` is
preserved in occurrence remarks, not interpreted as a biological stage.

Species, methods and units are sourced from Bernard et al. (2026),
https://doi.org/10.1038/s42003-026-10780-1, and its supplement.
Related dataset: https://doi.org/10.6084/m9.figshare.32978291.
Both dive events link through `parentEventID` to the FKt241214 cruise record
at Rolling Deck to Repository: https://doi.org/10.7284/910878.
The cruise is included in the Event core with this DOI as its `eventID` and
an empty `parentEventID`, so the event hierarchy is self-contained. Its date
interval comes from Supplementary Methods p.1. The converter checks that all
parent links resolve within the Event core and that the cruise is the single root.

## Interpretation

- The parent cruise retains the expedition interval
  `2024-12-15/2025-01-03`, sourced from Supplementary Methods p.1.
  The updated dive date ranges in `src/transform-data.R` and `event.txt` are:
  - Antarctic Sound, S0767: **21–22 December 2024** (`2024-12-21/22`).
  - Hook Ridge, S0770: **26–27 December 2024** (`2024-12-26/27`).
  These are dive-level date ranges, not individual specimen collection times.
  Event remarks, review notes and the validation report reflect these updated
  dive date ranges.
- Coordinates are converted from Notes-sheet DMS to decimal degrees.
  `decimalLatitude` and `decimalLongitude` are written with exactly four decimal
  places, including trailing zeros; missing coordinates are empty.
  The dive records currently specify `EPSG:4326` as the geodetic datum;
  positional uncertainty is left empty. The georeference remarks still state
  that the datum was not reported, so the datum attribution needs confirmation.
- Bottom survey depths are not assigned as individual capture depths.
- Temperatures come from the paper p.2, “Survey site observations”: Antarctic
  Sound mean bottom −1.35 °C; Hook Ridge mean bottom −1.21 °C, maximum within
  approximately 2 m of the vent 1.38 °C, and vent fluid >200 °C. The lower bound
  is retained as text. These are environmental summaries, not specimen exposure
  measurements. Instrument details come from Supplementary Methods p.1;
  summary uncertainty is unreported and left empty.
- P01 measurementTypeID is populated for 212 records (length, development stage,
  carbon/nitrogen mass fractions, isotopes and water temperatures). The 112 trace-element records
  and one vent-fluid temperature remain unmapped pending suitable terms. See
  `references/p01-mappings.md` for verified codes and mapping rationale.
- K038 phosphorus and zinc exceed the calibration range according to Table S3.
- Eleven specimens lack isotope results in this workbook, despite the
  supplement's statement about analysis of all Antarctic Sound specimens.
- Dataset-level publication metadata (e.g. EML contact/licensing information)
  is not included; add it when preparing an IPT publication.

The converter validates IDs, extension links, site consistency and expected
source coverage. It preserves the supplied workbook and references.
