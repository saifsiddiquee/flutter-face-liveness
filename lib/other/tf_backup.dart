import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteService {
  late Interpreter _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;

  // Singleton pattern
  static final TfliteService _instance = TfliteService._internal();

  factory TfliteService() {
    return _instance;
  }

  TfliteService._internal();

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/mobile_face_net.tflite',
      );

      // Get input and output tensor details
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;
    } catch (e) {
      // Handle model loading failure
    }
  }

  // Pre-process the image and run inference
  List<double> runInference(img.Image image) {
    // Resize the image to match the model's input shape (e.g., 112x112)
    final img.Image resizedImage = img.copyResize(
      image,
      width: _inputShape[1],
      height: _inputShape[2],
    );

    // Convert the image to a Float32List of normalized pixel values
    final Float32List inputBuffer = _imageToFloat32List(resizedImage);

    // Reshape the input to match the interpreter's expected input tensor
    // The model expects a batch, so it's [1, 112, 112, 3]
    final input = inputBuffer.reshape([1, _inputShape[1], _inputShape[2], 3]);

    // Create an output buffer. The output is typically [1, 192] or [1, 512]
    final output = List.filled(
      1 * _outputShape[1],
      0.0,
    ).reshape([1, _outputShape[1]]);

    // Run inference
    _interpreter.run(input, output);

    // The output is a 2D list, so we return the first (and only) item
    // This is the face embedding
    return (output[0] as List<dynamic>).cast<double>();
  }

  // Helper function to convert img.Image to a normalized Float32List
  Float32List _imageToFloat32List(img.Image image) {
    var buffer = Float32List(1 * _inputShape[1] * _inputShape[2] * 3);
    var bufferIndex = 0;

    // Normalize pixels to be between -1 and 1 (common for MobileFaceNet)
    // (pixel - 127.5) / 128.0
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        var pixel = image.getPixel(x, y);
        buffer[bufferIndex++] = (pixel.r - 127.5) / 128.0;
        buffer[bufferIndex++] = (pixel.g - 127.5) / 128.0;
        buffer[bufferIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }
    return buffer;
  }

  void close() {
    _interpreter.close();
  }
}
