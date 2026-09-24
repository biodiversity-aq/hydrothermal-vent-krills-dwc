# NERC P01 mappings

Verified against the NERC Vocabulary Server on 2026-09-21. Terms are accepted.
Identifiers use the canonical `http://vocab.nerc.ac.uk/collection/P01/current/`
prefix and a trailing slash. Existing descriptive measurementType text is retained.

| Measurement | P01 code | Verified version | Rationale |
|---|---|---|---|
| Total body length | TL01XX01 | 1 | Longest distance along the body axis; the source specifies rostrum to uropods. |
| Sex/maturity stage code | LSTAGE01 | 4 | Life-cycle development stage; original sex-specific Makarov and Denys codes retained. Sex is separately mapped in occurrence. |
| %C | CBDYXX01 | 1 | Carbon elemental content as percentage of dry mass in an organism identified elsewhere. |
| %N | NTDYXX01 | 1 | Nitrogen elemental content as percentage of dry mass in an organism identified elsewhere. |
| δ13C | C13BTX01 | 2 | Carbon-13 enrichment relative to VPDB in biota, measured by mass spectrometry. |
| δ15N | N15BTX01 | 1 | Nitrogen-15 enrichment relative to atmospheric air in biota, measured by mass spectrometry. |
| Bottom/near-vent water temperature | TEMPPR01 | 1 | Temperature of the water body; mean/maximum and spatial context are retained in measurementType and remarks. Verified 2026-09-22. |

Definitions are available at each canonical term URI. P06 mappings linked by
these P01 records are UXMM (millimetres), XXXX (not applicable), UPCT (percent),
and UPPT (parts per thousand). Temperature uses UPAA (degrees Celsius, version 2;
verified 2026-09-22). No numerical conversions are applied.

## Unresolved trace elements

As, Ba, Cd, Co, Cr, Cu, Fe, Mn, Mo, Ni, P, Pb, V and Zn are concentrations
per dry mass of krill tissue (mg/kg). Searching the P01 collection's preferred
labels did not identify suitable krill or generic-biota dry-weight terms for
these measurements. Species-specific fish/mollusc terms, wet-weight terms,
and sediment/water terms are not suitable substitutes. Their 112 measurementTypeID
cells remain blank pending suitable P01 terms or a vocabulary request to BODC.

## Environmental temperatures

The main paper p.2 reports three bottom/near-vent water temperature summaries
for the two sampled sites, mapped to TEMPPR01. Their occurrenceID is empty
because these are event-level environmental measurements. The fourth record,
Hook Ridge vent fluid >200 °C, retains its lower-bound qualifier and remains
unmapped: the verified water-column term is not assigned to vent source fluid.
Quest Caldera temperatures belong to a separate cruise/site outside these events.

Coverage: 212 of 325 measurement records mapped, across seven P01 terms.
The pipeline checks this coverage and ensures only trace-element records and
the vent-fluid temperature are unmapped.
