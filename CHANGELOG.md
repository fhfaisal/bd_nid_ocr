## 1.0.0

Initial release. Ported from an existing production NID-scanning module as
a framework-agnostic package (no GetX/Riverpod/Bloc/Provider dependency).

- `NidOcr`: `scan()` runs ML Kit text recognition (front + back) and PDF417
  barcode scanning concurrently, then parses the result into structured NID
  fields. `extractRaw()` exposes the unparsed OCR/barcode output.
  `cropToViewport()` auto-crops a captured image to a card-shaped viewport.
- `NidScanParser`: pure-Dart regex/MRZ field extraction, usable standalone
  against already-captured OCR text without ML Kit.
- `NidCard`, `NidScanResult`, `RawNidScan`: structured result models.
- `NidOcrException` hierarchy (`TextRecognitionException`,
  `BarcodeScanException`, `NidParsingException`) — no `dartz`/`Either`.
- Bengali/Devanagari + Latin OCR, MRZ (`I<BGD` anchor) parsing, and PDF417
  barcode payload decoding, all specific to the Bangladesh NID format.

See [`README.md`](README.md#known-limitations) for known limitations
(blood-group sign extraction, silent crop fallback, no default capture UI).
