import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// Helper class to pass CameraImage data to an isolate
class IsolateImageData {
  final int width;
  final int height;
  final ImageFormatGroup imageFormatGroup;
  final List<Uint8List> planes;

  IsolateImageData({
    required this.width,
    required this.height,
    required this.imageFormatGroup,
    required this.planes,
  });

  factory IsolateImageData.fromCameraImage(CameraImage cameraImage) {
    return IsolateImageData(
      width: cameraImage.width,
      height: cameraImage.height,
      imageFormatGroup: cameraImage.format.group,
      planes: cameraImage.planes
          .map((Plane p) => Uint8List.fromList(p.bytes))
          .toList(),
    );
  }
}

// This file contains heavy image processing logic
// It's good practice to isolate it
class ImageConverter {
  // Converts a CameraImage to an img.Image (RGB)
  // MUST BE a static method to be used in compute()
  static img.Image? convertCameraImage(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      // Use the YUV420 conversion
      return _convertYUV420(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
      // Use the NV21 conversion
      return _convertNV21(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // Use the BGRA8888 conversion (common on iOS)
      return _convertBGRA8888(cameraImage);
    } else {
      debugPrint('Image format not supported: ${cameraImage.format.group}');
      return null;
    }
  }

  // Runs conversion in background isolate
  static Future<img.Image?> convertCameraImageAsync(CameraImage cameraImage) {
    return compute(_convertFromIsolate, cameraImage);
  }

  // Isolate entry
  static img.Image? _convertFromIsolate(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.nv21) {
      return _convertNV21FromPlanes(cameraImage);
    } else {
      return null;
    }
  }

  static Uint8List convertImageToPng(img.Image image) {
    return img.encodePng(image);
  }

  // --- Private Conversion Helpers ---
  // MUST BE static methods
  static img.Image _convertYUV420(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final img.Image image = img.Image(width: width, height: height);
    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel!; // Should be 1
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!; // Should be 1

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = (y * yRowStride) + (x * yPixelStride);
        final int yValue = yPlane.bytes[yIndex];

        // U and V planes are subsampled by 2
        final int uvIndex =
            ((y ~/ 2) * uvRowStride) + ((x ~/ 2) * uvPixelStride);
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        final int r = (yValue + (1.370705 * (vValue - 128))) as int;
        final int g =
            (yValue - (0.698001 * (vValue - 128)) - (0.337633 * (uValue - 128)))
                as int;
        final int b = (yValue + (1.732446 * (uValue - 128))) as int;

        image.setPixelRgba(
          x,
          y,
          r.clamp(0, 255).toInt(),
          g.clamp(0, 255).toInt(),
          b.clamp(0, 255).toInt(),
          255,
        );
      }
    }
    return image;
  }

  // Handles NV21 (common on Android)
  // 1 plane for Y, 1 plane for V/U interleaved.
  static img.Image _convertNV21(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final img.Image image = img.Image(width: width, height: height);
    final Plane yPlane = cameraImage.planes[0];
    // For NV21, plane[1] is an interleaved V/U plane.
    final Plane vuPlane = cameraImage.planes[1];

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel!; // This is 1

    final int uvRowStride = vuPlane.bytesPerRow;
    final int uvPixelStride = vuPlane.bytesPerPixel!; // This is 2

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = (y * yRowStride) + (x * yPixelStride);
        final int yValue = yPlane.bytes[yIndex];

        // U and V are interleaved, subsampled by 2
        final int uvIndex =
            ((y ~/ 2) * uvRowStride) + ((x ~/ 2) * uvPixelStride);

        // For NV21, V and U are interleaved
        // V is at uvIndex, U is at uvIndex + 1
        final int vValue = vuPlane.bytes[uvIndex];
        final int uValue = vuPlane.bytes[uvIndex + 1];

        final int r = (yValue + (1.370705 * (vValue - 128))) as int;
        final int g =
            (yValue - (0.698001 * (vValue - 128)) - (0.337633 * (uValue - 128)))
                as int;
        final int b = (yValue + (1.732446 * (uValue - 128))) as int;

        image.setPixelRgba(
          x,
          y,
          r.clamp(0, 255).toInt(),
          g.clamp(0, 255).toInt(),
          b.clamp(0, 255).toInt(),
          255,
        );
      }
    }
    return image;
  }

  static img.Image _convertNV21FromPlanes(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final img.Image rgb = img.Image(width: width, height: height);

    final bytes = image.planes[0].bytes;
    final int ySize = width * height;
    final yPlane = bytes.sublist(0, ySize);
    final vuPlane = bytes.sublist(ySize); // interleaved VU

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yValue = yPlane[y * width + x] & 0xFF;

        final int uvIndex = (y ~/ 2) * width + (x ~/ 2) * 2;
        final int vValue = vuPlane[uvIndex] & 0xFF;
        final int uValue = vuPlane[uvIndex + 1] & 0xFF;

        double r = yValue + 1.402 * (vValue - 128);
        double g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        double b = yValue + 1.772 * (uValue - 128);

        rgb.setPixelRgba(
          x,
          y,
          r.clamp(0, 255).toInt(),
          g.clamp(0, 255).toInt(),
          b.clamp(0, 255).toInt(),
          255,
        );
      }
    }
    return rgb;
  }

  // Handles BGRA8888 (common on iOS)
  // 1 plane with interleaved B, G, R, A data.
  static img.Image _convertBGRA8888(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }
}
