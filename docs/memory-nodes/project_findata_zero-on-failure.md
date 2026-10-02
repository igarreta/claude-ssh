---
name: project_findata_zero-on-failure
description: findata on contabo2 writes 0.0 silently for any value a scraper can't read; Dolar Oficial fixed 10-02, general fix pending
metadata:
  type: project
---

findata (contabo2, `~/findata`) writes 0.0 for every value it fails to read, usually with nothing in the log.

**Why:** a source-site change only shows up as zeros in the CSV/email. That's how Dolar Oficial went unnoticed for 4 days.

**How to apply:** a 0.0 in findata means "not read", never a real value. The user wants a general fix for all of them later. Detail: `docs/2026-10-02_contabo2_findata-dolar-oficial.md`.
