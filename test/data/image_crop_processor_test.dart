// Ported from microzen/test/app/modules/MIS/scan_nid/data/datasources/
// image_processor_test.dart — same crop-math/fallback assertions, retargeted
// at the package's ImageCropProcessor. See docs/ARCHITECTURE.md §14.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bd_nid_ocr/src/data/image/image_crop_processor.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// A minimal fake so `getTemporaryDirectory()` resolves to a real, writable
/// directory under test — the plugin's platform channel is never actually
/// invoked.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('image_crop_processor_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File writeJpg(String name, img.Image image) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(img.encodeJpg(image));
    return file;
  }

  group('ImageCropProcessor.cropImage', () {
    test(
      'crops a wide source image down to a narrower viewport aspect ratio',
      () async {
        // Source is 3:1 landscape; viewport is 1:2 portrait — imageRatio
        // (3.0) is NOT < viewportRatio (0.5), so cropHeight stays the full
        // source height and cropWidth shrinks to match the viewport ratio.
        final source = writeJpg(
          'source_wide.jpg',
          img.Image(width: 300, height: 100),
        );

        final result = await ImageCropProcessor().cropImage(source, 100, 200);

        expect(result, isNotNull);
        expect(result!.existsSync(), isTrue);
        expect(result.path, startsWith(tempDir.path));
        expect(result.path, contains('cropped_'));

        final cropped = img.decodeImage(result.readAsBytesSync())!;
        expect(cropped.height, 100);
        expect(cropped.width, 50); // 100 * (100/200)
      },
    );

    test(
      'crops a tall source image down to a wider viewport aspect ratio',
      () async {
        // Source is 1:3 portrait; viewport is 3:1 landscape — imageRatio
        // (0.333) IS < viewportRatio (3.0), so cropWidth stays the full
        // source width and cropHeight shrinks to match the viewport ratio.
        final source = writeJpg(
          'source_tall.jpg',
          img.Image(width: 100, height: 300),
        );

        final result = await ImageCropProcessor().cropImage(source, 300, 100);

        expect(result, isNotNull);
        final cropped = img.decodeImage(result!.readAsBytesSync())!;
        expect(cropped.width, 100);
        expect(cropped.height, 33); // (100 / 3.0).round()
      },
    );

    test(
      'returns null when the source file is not a decodable image',
      () async {
        // Long enough, and with no format's magic-number signature, for every
        // decoder's sniff check to cleanly reject it rather than under-read.
        final notAnImage = File('${tempDir.path}/not_an_image.jpg')
          ..writeAsStringSync('not a real image file' * 20);

        final result = await ImageCropProcessor().cropImage(
          notAnImage,
          100,
          100,
        );

        expect(result, isNull);
      },
    );
  });
}
