# bd_nid_ocr

Framework-agnostic Bangladesh NID (National ID) card OCR: image cropping,
ML Kit text/barcode recognition, and regex/MRZ-based structured field
extraction — as a plain-Dart/Flutter API with **zero dependency on any
state-management framework** (no GetX, Riverpod, Bloc, or Provider).

Extracted from Microzen's `scan_nid` module — a port, not a rewrite.

## What this package owns

- Cropping a captured image to a card-shaped viewport.
- ML Kit text recognition (Latin + Devanagari-as-Bengali) and PDF417
  barcode scanning.
- Normalizing OCR text and extracting structured NID fields via regex.
- MRZ (machine-readable zone) parsing.
- Decoding the PDF417 barcode payload into a key/value map.
- Disposing native ML Kit resources.

## What this package does NOT own

Camera UI, navigation, state management, persistence, session/auth, and
Microzen (or any other consuming app) — all of that stays entirely in your
app. This package has no default capture screen; you supply front/back
images however you like (your own camera UI, `image_picker`, etc.) and hand
them to `NidOcr` as `File`s.

This is Bangladesh-NID-specific by design — Bengali/Devanagari OCR, the MRZ
`I<BGD` anchor, and the {10, 13, 17}-digit NID length whitelist are baked
in, not configurable. No multi-country support exists or is planned for v1.

## Install

```yaml
dependencies:
  bd_nid_ocr:
    path: ../bd_nid_ocr # or a git/pub.dev reference once published
```

## Usage

```dart
import 'dart:io';
import 'package:bd_nid_ocr/bd_nid_ocr.dart';

final nidOcr = NidOcr();

try {
  final NidScanResult result = await nidOcr.scan(
    frontImage: File('/path/to/front.jpg'),
    backImage: File('/path/to/back.jpg'),
  );
  print(result.card.nidNumber);
  print(result.card.name);
  print(result.barcodeData);
} on NidOcrException catch (e) {
  // TextRecognitionException, BarcodeScanException, or NidParsingException.
  // Display this however your app displays errors — the package never
  // shows a snackbar/dialog itself.
} finally {
  await nidOcr.dispose(); // releases ML Kit recognizers — always call this
}
```

Cropping a freshly-captured image to a viewport (mirrors the original
Microzen flow of cropping immediately after each capture, before both
images exist):

```dart
final cropped = await nidOcr.cropToViewport(
  image: File('/path/to/capture.jpg'),
  viewportWidth: 327,
  viewportHeight: 240,
);
```

`cropToViewport` never throws — on any failure (decode error, I/O error,
etc.) it silently returns the original image unchanged. This preserves
Microzen's existing behavior exactly, and is flagged as a candidate future
improvement rather than something to change silently.

If you already have raw OCR text (e.g. from your own pipeline, or a saved
fixture) and want structured fields without images or ML Kit at all, use
the parser directly:

```dart
const parser = NidScanParser();
final card = parser.parse(frontText: myFrontText, backText: myBackText);
```

### Errors

```dart
sealed class NidOcrException implements Exception { ... }
class TextRecognitionException extends NidOcrException { ... }
class BarcodeScanException extends NidOcrException { ... }
class NidParsingException extends NidOcrException { ... }
```

There is no `ImageProcessingException` — `cropToViewport` never throws (see
above), so no exception type for it is exposed.

## Using without any state-management framework

```dart
class ScanPage extends StatefulWidget {
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _nidOcr = NidOcr();
  NidScanResult? _result;

  Future<void> _scan(File front, File back) async {
    final result = await _nidOcr.scan(frontImage: front, backImage: back);
    setState(() => _result = result);
  }

  @override
  void dispose() {
    _nidOcr.dispose();
    super.dispose();
  }

  // ...
}
```

See `example/` for a complete runnable app built exactly this way.

## Using with Riverpod

```dart
final nidOcrProvider = Provider<NidOcr>((ref) {
  final nidOcr = NidOcr();
  ref.onDispose(nidOcr.dispose);
  return nidOcr;
});

final nidScanProvider = FutureProvider.family<NidScanResult, (File, File)>(
  (ref, images) => ref.read(nidOcrProvider).scan(
    frontImage: images.$1,
    backImage: images.$2,
  ),
);
```

## Using with Bloc

```dart
class NidScanCubit extends Cubit<AsyncSnapshot<NidScanResult>> {
  NidScanCubit() : _nidOcr = NidOcr(), super(const AsyncSnapshot.waiting());

  final NidOcr _nidOcr;

  Future<void> scan(File front, File back) async {
    try {
      final result = await _nidOcr.scan(frontImage: front, backImage: back);
      emit(AsyncSnapshot.withData(ConnectionState.done, result));
    } on NidOcrException catch (e) {
      emit(AsyncSnapshot.withError(ConnectionState.done, e));
    }
  }

  @override
  Future<void> close() {
    _nidOcr.dispose();
    return super.close();
  }
}
```

## Using with GetX

```dart
class ScanNidController extends GetxController {
  final _nidOcr = NidOcr();
  final nidData = Rxn<NidCard>();

  Future<void> scan(File front, File back) async {
    final result = await _nidOcr.scan(frontImage: front, backImage: back);
    nidData.value = result.card;
  }

  @override
  void onClose() {
    _nidOcr.dispose();
    super.onClose();
  }
}
```

## Platform setup

Your app (not this package) needs:

**Android** — `google_mlkit_text_recognition` requires the Devanagari
script model as a separate Gradle dependency. Add to your app's
`android/app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
```

*(Confirmed required in Microzen's own `build.gradle.kts`. Not independently
re-verified against the current `google_mlkit_text_recognition` plugin's
internal Android module structure. Treat as "known to work," not
"verified minimal.")*

**iOS** — if you also capture images yourself with `camera`/`image_picker`,
your `Info.plist` needs the usual camera/photo-library usage descriptions
(`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`). This
package itself does not touch the camera — it only processes `File`s you
already have — so these are only required if *your* capture code needs
them, not because of this package.

## Known limitations

- Blood group extraction cannot reliably preserve a `-` sign in most
  realistic OCR text. This is a pre-existing regex quirk, ported as-is, not
  introduced or fixed during extraction.
- `cropToViewport` never surfaces crop failures — see above.
- No default capture UI ships in this version — bring your own camera code.

## Publishing to pub.dev

This package currently ships with `publish_to: 'none'` in `pubspec.yaml`.
Before removing that line and running `dart pub publish`, work through this
checklist:

1. **Resolve the ML Kit redistribution licensing question first.** This is
   the actual blocker, not a formality — `google_mlkit_text_recognition`
   and `google_mlkit_barcode_scanning` wrap Google's ML Kit, and its
   redistribution terms for a *published, third-party* Flutter package have
   not been independently verified. Confirm this before doing anything
   below. **No data available on this yet** — don't publish until it's
   checked.
2. **Pick and add a real license.** `LICENSE` currently contains a
   placeholder (`TODO: Add your license here.`). Pub.dev's scoring and
   `dart pub publish` both expect an OSI-approved license (MIT and
   Apache-2.0 are the common choices for Flutter packages) as actual file
   content, not a TODO.
3. **Fill in `pubspec.yaml` metadata pub.dev requires/rewards:**
   - `homepage:` and/or `repository:` — currently empty. Needs a real
     public repo URL (push this package to GitHub/GitLab first).
   - `version:` — bump from `0.0.1` to `1.0.0` (or whatever you consider
     first-stable) once you're ready to publish; pub.dev treats `0.x` as
     pre-release but it's not required.
   - `description:` — current one is fine (60–180 chars, already is).
4. **Write real `CHANGELOG.md` entries.** It currently just says `TODO:
   Describe initial release.` — pub.dev penalizes placeholder changelogs.
5. **Add dartdoc comments to public API surface** (`NidOcr`, `NidScanResult`,
   `NidCard`, exception types, etc.) if not already fully documented —
   this is a chunk of the pub.dev score.
6. **Verify `example/` runs standalone** with a `git`/path dependency swapped
   for the real pub.dev name once published — pub.dev requires a working
   example.
7. **Dry-run before publishing for real:**
   ```bash
   dart pub publish --dry-run
   ```
   Fix every warning it prints (missing files, oversized package, invalid
   pubspec fields, etc.).
8. **Check name availability** — `bd_nid_ocr` must not already be taken on
   pub.dev; search before you're committed to the name.
9. **Publish:**
   ```bash
   dart pub publish
   ```
   This is irreversible for that version number — once published, a
   version cannot be unpublished except within a short grace window and
   under pub.dev's retraction rules. Double-check everything above first.
