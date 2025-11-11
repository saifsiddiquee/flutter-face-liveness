import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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
      debugPrint('TFLite model loaded successfully.');

      // Get input and output tensor details
      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;

      debugPrint('Input Shape: $_inputShape');
      debugPrint('Output Shape: $_outputShape');
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
    }
  }

  // Pre-process the image and run inference
  List<double> runInference(img.Image image) {
    // Resize the image to match the model's input shape
    // Assumes input shape is [1, H, W, 3]
    final img.Image resizedImage = img.copyResize(
      image,
      width: _inputShape[1],
      height: _inputShape[2],
    );

    // Convert the image to a Float32List of normalized pixel values
    final Float32List inputBuffer = _imageToFloat32List(resizedImage);

    // Reshape the input to match the interpreter's expected input tensor
    // Use the shape from the model directly
    final input = inputBuffer.reshape(_inputShape);

    // --- FIX: Create a dynamic output buffer ---
    // Calculate the total number of elements in the output tensor
    // e.g., [1, 192] -> 192. e.g., [1, 1, 192] -> 192.
    final int outputSize = _outputShape.reduce(
      (value, element) => value * element,
    );

    // Create a flat list to hold the output
    final List<dynamic> outputList = List.filled(outputSize, 0.0);

    // Reshape it to the model's expected output shape
    // e.g., [1, 192] or [1, 1, 192] etc.
    final output = outputList.reshape(_outputShape);
    // --- END OF FIX ---

    // Run inference
    _interpreter.run(input, output);

    // The output is a multi-dimensional list. We need to flatten it.
    // e.g., [[0.1, 0.2, ...]] -> [0.1, 0.2, ...]
    final List<dynamic> flattenedOutput = (output)
        .expand((e) => e is List ? e : [e])
        .toList();

    return flattenedOutput.cast<double>();
  }

  // Helper function to convert img.Image to a normalized Float32List
  Float32List _imageToFloat32List(img.Image image) {
    // --- FIX: Use all dimensions from _inputShape to create buffer ---
    // This dynamically calculates the buffer size
    final int bufferSize = _inputShape.reduce(
      (value, element) => value * element,
    );

    var buffer = Float32List(bufferSize);
    // --- END OF FIX ---

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
