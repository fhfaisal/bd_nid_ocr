# pub.dev publish checklist

Source: [`pana`](https://pub.dev/packages/pana) `0.23.17`, run locally against this
package. Point model verified against `dart-lang/pana` source
(`lib/src/report/{template,static_analysis,dependencies,multi_platform}.dart`,
`lib/src/dartdoc/dartdoc.dart`, `master` branch).

| Run | Score | When |
|---|---|---|
| Baseline audit | 120/160 | 2026-08-09, before any changes |
| After mechanical fixes | 140/160 | 2026-08-09 |
| **After license + publish_to + version bump** | **160/160** | 2026-08-09 |

## Everything below is done

- [x] `dart format .` — static analysis 40→50/50.
- [x] Widened `google_mlkit_barcode_scanning`/`google_mlkit_text_recognition`
      to latest stable minors; re-verified with `dart analyze` + `flutter test`
      (51/51 passing) — dependencies 30→40/40.
- [x] Trimmed `pubspec.yaml` `description` to 162 chars; added
      `homepage`/`repository` → [github.com/fhfaisal/bd_nid_ocr](https://github.com/fhfaisal/bd_nid_ocr)
      (public, `git init`'d and pushed this session — repo had no history before).
- [x] **ML Kit redistribution question — resolved, not deferred.** Read
      against the primary sources: [Google ML Kit Terms](https://developers.google.com/ml-kit/terms)
      incorporate the [Google APIs ToS](https://developers.google.com/terms),
      whose relevant clause (§4a(1)) bars building a *competing API client*,
      not depending on an existing published wrapper. `bd_nid_ocr` bundles no
      ML Kit binary — it depends on the existing MIT-licensed
      `google_mlkit_text_recognition`/`google_mlkit_barcode_scanning`
      ([flutter-ml/google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter))
      exactly like an app would. Precedent: [10+ published pub.dev packages](https://pub.dev/packages?q=dependency%3Agoogle_mlkit_text_recognition)
      already do this, including `cnic_scanner` (Pakistan NID scanner) and
      `inapp_flutter_kyc`. Not formal legal advice — you accepted this reading
      and chose to proceed.
- [x] `LICENSE` — MIT, Faisal Hasan, 2026. License: 0→10/10.
- [x] Removed `publish_to: 'none'`.
- [x] `version:` 0.0.1 → 1.0.0.
- [x] `CHANGELOG.md` — real 1.0.0 release notes (superseded the `TODO`).
- [x] Confirmed `bd_nid_ocr` is unclaimed on pub.dev (404 as of 2026-08-09).
- [x] `dart pub publish --dry-run` — 0 warnings.

## Left — the one step that's genuinely irreversible

- [ ] `dart pub publish`. Everything above is done and verified; this is the
      actual publish, and I won't run it without you saying so explicitly —
      once a version is up, it can only be retracted within a short grace
      window under pub.dev's rules, not unpublished outright.
