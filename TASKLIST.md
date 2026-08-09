# pub.dev publish checklist

Source: [`pana`](https://pub.dev/packages/pana) `0.23.17`, run locally against this
package. Point model verified against `dart-lang/pana` source
(`lib/src/report/{template,static_analysis,dependencies,multi_platform}.dart`,
`lib/src/dartdoc/dartdoc.dart`, `master` branch) — the pub.dev score isn't
published anywhere as a spec, so these numbers are read out of the scoring
tool itself, not estimated.

| Run | Score | When |
|---|---|---|
| Baseline audit | 120/160 | 2026-08-09, before any changes |
| After mechanical fixes (this session) | **140/160** | 2026-08-09 |
| Ceiling until the 2 items below are resolved | 140/160 | — |

## Done this session (mechanical, verified)

- [x] `dart format .` — fixed 6 files with formatting drift. **Static analysis: 40→50/50.**
- [x] Widened `google_mlkit_barcode_scanning` (`^0.14.2`→`^0.15.0`) and
      `google_mlkit_text_recognition` (`^0.15.1`→`^0.16.0`) to the latest stable
      minors. Re-ran `dart analyze` (clean) and `flutter test` (51/51 passing)
      against the new versions — no behavior change surfaced.
      **Dependencies: 30→40/40.**
- [x] Trimmed `pubspec.yaml` `description` from 212→162 chars (pana's cap is 180).
- [x] Added `homepage`/`repository` pointing to
      [github.com/fhfaisal/bd_nid_ocr](https://github.com/fhfaisal/bd_nid_ocr).
- [x] `git init`, initial commit, pushed to a new **public** GitHub repo
      (`fhfaisal/bd_nid_ocr`, created via `gh repo create`).

Documentation (20/20) and platform support (20/20) were already at max before
any changes — no action was needed there. Don't spend effort chasing web/desktop
support to "improve" platform score; it's already full for what this package
can honestly support (Android/iOS, inherited from the ML Kit plugins).

## Remaining — blocks 140→160, needs your call, not mine

1. **Resolve ML Kit redistribution licensing.** `google_mlkit_text_recognition`
   and `google_mlkit_barcode_scanning` wrap Google's ML Kit; its redistribution
   terms for a published third-party Flutter package haven't been independently
   verified. **No data available on this** — it's a legal read, not something
   `pana` checks or I can clear. Do this before either item below, since both
   assume the package is actually clear to publish.
2. **Add a real LICENSE.** `LICENSE` is still `TODO: Add your license here.` —
   pana recognizes no license, which is a hard 0/10. MIT or Apache-2.0 are the
   standard picks for Flutter packages; which one is your call (Apache-2.0 adds
   an explicit patent grant, relevant given #1). **Convention: +10 → 150/160.**
3. **Remove `publish_to: 'none'` and push.** This is the actual gate on the
   remaining 10 points — pana's repository-URL check clones the pushed repo and
   explicitly rejects it while `publish_to` is set:
   > *pubspec.yaml from the repository defines `publish_to`, thus, we are
   > unable to verify the package is published from here.*
   Only remove this once #1 and #2 are actually resolved — it's the line that's
   currently preventing an accidental `dart pub publish`.
   **Convention: +10 → 160/160.**

## After 160/160 — still required before `dart pub publish`, not scored

These don't move the pana score but `dart pub publish` needs them:

4. Bump `version:` from `0.0.1` to your intended first release (`1.0.0` or
   similar) — pub.dev allows `0.x` but you said you want a real first release.
5. Write real `CHANGELOG.md` content. Currently just `TODO: Describe initial
   release.` — this does **not** cost points (pana's changelog check only
   verifies the current version string is present, which it already is), but
   it's a poor first impression on the package page. Correcting the repo's own
   prior README note, which claimed this *does* affect scoring — it doesn't,
   per the actual `template.dart` check.
6. Check `bd_nid_ocr` isn't already taken on pub.dev.
7. `dart pub publish --dry-run` — re-run after #3/#4, fix anything new it flags.
8. `dart pub publish` — irreversible for that version number (retraction rules
   apply after, no plain unpublish). Double-check #1 first; this is the step
   that can't be walked back cheaply.

## Note

`README.md`'s old "Publishing to pub.dev" section duplicated most of this and
had gone stale (e.g. claiming the changelog affects score, which per pana's
source it doesn't). Replace it with a pointer to this file so there's one
source of truth — see suggested edit below.
