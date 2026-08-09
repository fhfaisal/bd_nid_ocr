import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Center-crops an image to a target viewport aspect ratio, baking in EXIF
/// orientation first.
///
/// Returns `null` when the image can't be decoded, rather than throwing —
/// callers (see [NidOcr.cropToViewport]) use that to silently fall back to
/// the original image. This behavior is closer to a latent bug than an
/// intentional design (see "Known limitations" in the README), but it's
/// preserved deliberately rather than silently "fixed" here.
class ImageCropProcessor {
  Future<File?> cropImage(
    File image,
    double viewportWidth,
    double viewportHeight,
  ) async {
    final Uint8List bytes = await image.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return null;

    if (originalImage.exif.exifIfd.orientation != -1) {
      originalImage = img.bakeOrientation(originalImage);
    }

    final double viewportRatio = viewportWidth / viewportHeight;
    final double imageRatio = originalImage.width / originalImage.height;

    int cropWidth;
    int cropHeight;

    if (imageRatio < viewportRatio) {
      cropWidth = originalImage.width;
      cropHeight = (cropWidth / viewportRatio).round();
    } else {
      cropHeight = originalImage.height;
      cropWidth = (cropHeight * viewportRatio).round();
    }

    if (cropWidth > originalImage.width) cropWidth = originalImage.width;
    if (cropHeight > originalImage.height) cropHeight = originalImage.height;

    final int cropX = (originalImage.width - cropWidth) ~/ 2;
    final int cropY = (originalImage.height - cropHeight) ~/ 2;

    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final String dir =
        (await getTemporaryDirectory()).path; // Use temp dir for cropped images
    final String filename =
        'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String resultPath = path.join(dir, filename);

    final croppedFile = File(resultPath);
    await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));
    return croppedFile;
  }
}
