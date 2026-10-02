# findata: Dolar Oficial read as 0.0

**Status:** open
**Status detail:** Dolar Oficial fixed (findata `fe50e46`); general 0.0-on-failure handling pending
**Host:** contabo2
**Supersedes:** —
**Superseded-by:** —

## Symptom

From 2026-09-28, the `Dolar Oficial` column in `~/findata/var/findata.csv` is `0.0`
(rows 09-28 → 10-01). The log showed no error.

## Cause

dolarhoy.com removed the "Dólar Oficial" tile from its homepage on 2026-09-28 (replaced by
"Dólar Digital (USDC)" and "Dólar Tarjeta"). `sf_00_dolarhoy` reads tiles by title and uses
`data.get("Dólar Oficial", 0.0)`, so a missing tile becomes 0.0 silently.

## Fix (findata `fe50e46`, pushed to `igarreta/findata` master)

New `get_dolar_oficial()` in `bin/findata.py`: when the homepage tile is missing, it reads
the Venta value from `https://dolarhoy.com/cotizacion-dolar-oficial` (same source as the
historical series). It logs an error if that fails too. Tested on its own: returned 1545.0,
matching dolarapi.com (`https://dolarapi.com/v1/dolares/oficial`, a usable fallback).

## Open

- **Every scraper writes 0.0 for a value it can't read**, usually with no error logged.
  This needs a general fix later (log a clear error for each unread value, and decide
  between empty, last value, or a marked value in the CSV/email).
- The 0.0 rows for 09-28 → 10-01 are not backfilled.
