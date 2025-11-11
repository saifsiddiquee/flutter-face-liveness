import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:liveness_app/profile_page.dart';
import 'package:liveness_app/registration_page.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/user_profile.dart';
import 'services/database_service.dart';
import 'services/tf_lite_service.dart';
import 'util/image_converter.dart';

// Enum to manage the liveness steps
enum LivenessStep {
  initial,
  turnLeft,
  turnRight,
  blink,
  smile,
  processing, // Added a processing step
  complete,
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  CameraDescription? _frontCamera;

  // --- ML Kit Face Detection ---
  late final FaceDetector _faceDetector;
  bool _isDetecting = false;
  LivenessStep _currentStep = LivenessStep.initial;
  String _instructionText = 'Please look at the camera';

  final TfliteService _tfliteService = TfliteService();
  final DatabaseService _databaseService = DatabaseService();

  // --- Orientation ---
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  // --- Captured Data ---
  CameraImage? _capturedImage;
  Face? _capturedFace;

  // --- Liveness Thresholds ---
  final double _headTurnThreshold = 35.0; // Degrees
  final double _eyeOpenThreshold = 0.2; // Probability
  final double _smileThreshold = 0.8; // Probability

  @override
  void initState() {
    super.initState();
    // Initialize the FaceDetector
    final options = FaceDetectorOptions(
      enableClassification: true, // For smile and eye open probability
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);

    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.stopImageStream(); // Stop the stream on dispose
    _controller?.dispose();
    _faceDetector.close(); // Dispose the detector
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // 1. Request camera permission
    var cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showErrorSnackbar('Camera permission is required to proceed.');
      return;
    }

    // 2. Get available cameras
    final cameras = await availableCameras();

    // 3. Find the front-facing camera
    _frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // 4. Initialize the CameraController
    _controller = CameraController(
      _frontCamera!,
      ResolutionPreset.high,
      enableAudio: false,
      // IMPORTANT: Set image format for ML Kit
      // Use nv21 for Android, bgra8888 for iOS
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      _controller!.lockCaptureOrientation();

      // Listen for device orientation changes
      _controller!.addListener(() {
        if (mounted &&
            _deviceOrientation != _controller!.value.deviceOrientation) {
          setState(() {
            _deviceOrientation = _controller!.value.deviceOrientation;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        // 5. Start the image stream
        _startImageStream();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to initialize camera: $e');
      debugPrint("Camera initialization error: $e");
    }
  }

  void _startImageStream() {
    if (_controller == null) return;

    _controller!.startImageStream((CameraImage image) {
      if (_isDetecting ||
          _currentStep == LivenessStep.complete ||
          _currentStep == LivenessStep.processing) {
        return;
      }

      _isDetecting = true;

      // Store the latest image and face data
      // We'll use this for recognition after the smile step
      _capturedImage = image;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage cameraImage) async {
    // Create InputImage from CameraImage
    final inputImage = _inputImageFromCameraImage(cameraImage);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    // Process the image
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      // No face detected, reset to initial if needed or show message
      setState(() {
        if (_currentStep != LivenessStep.initial) {
          _instructionText = 'Please keep your face in the frame';
        }
      });
      _capturedFace = null;
      _isDetecting = false;
      return;
    }

    // We only care about the first face detected
    final face = faces[0];
    _capturedFace = face; // Store the latest face
    _updateLivenessStep(face);

    _isDetecting = false;
  }

  void _updateLivenessStep(Face face) {
    switch (_currentStep) {
      case LivenessStep.initial:
        // Move to the first step
        setState(() {
          _currentStep = LivenessStep.turnLeft;
          _instructionText = 'Turn your head to the left';
        });
        break;

      case LivenessStep.turnLeft:
        if (face.headEulerAngleY != null &&
            face.headEulerAngleY! > _headTurnThreshold) {
          setState(() {
            _currentStep = LivenessStep.turnRight;
            _instructionText = 'Now turn your head to the right';
          });
        }
        break;

      case LivenessStep.turnRight:
        if (face.headEulerAngleY != null &&
            face.headEulerAngleY! < -_headTurnThreshold) {
          setState(() {
            _currentStep = LivenessStep.blink;
            _instructionText = 'Blink your eyes';
          });
        }
        break;

      case LivenessStep.blink:
        if (face.leftEyeOpenProbability != null &&
            face.rightEyeOpenProbability != null &&
            face.leftEyeOpenProbability! < _eyeOpenThreshold &&
            face.rightEyeOpenProbability! < _eyeOpenThreshold) {
          setState(() {
            _currentStep = LivenessStep.smile;
            _instructionText = 'Now, please smile';
          });
        }
        break;

      case LivenessStep.smile:
        if (face.smilingProbability != null &&
            face.smilingProbability! > _smileThreshold) {
          setState(() {
            _currentStep = LivenessStep.processing;
            _instructionText = 'Processing... Please wait';
          });
          _onLivenessComplete();
        }
        break;

      case LivenessStep.processing:
      case LivenessStep.complete:
        break;
    }
  }

  Future<void> _onLivenessComplete() async {
    // Stop stream and dispose resources
    await _controller?.stopImageStream();
    _faceDetector.close();

    // Ensure we have the last captured image and face
    if (_capturedImage == null || _capturedFace == null) {
      _showErrorSnackbar('Failed to capture face data. Please try again.');
      return;
    }
    try {
      // 1. Convert CameraImage to img.Image (RGB)
      final img.Image? rgbImage = await ImageConverter.convertCameraImageAsync(
        _capturedImage!,
      );

      if (rgbImage == null) {
        _showErrorSnackbar('Failed to process image. Please try again.');
        return;
      }

      // 2. Crop the face from the image
      final Rect boundingBox = _capturedFace!.boundingBox;
      final img.Image croppedFace = img.copyCrop(
        rgbImage,
        x: boundingBox.left.toInt(),
        y: boundingBox.top.toInt(),
        width: boundingBox.width.toInt(),
        height: boundingBox.height.toInt(),
      );

      // 3. Run TFLite inference to get the embedding
      final List<double> faceEmbedding = _tfliteService.runInference(
        croppedFace,
      );

      // 4. Liveness is fully complete
      setState(() {
        _currentStep = LivenessStep.complete;
        _instructionText = 'Verification Complete!';
      });

      // 5. Find a matching user
      final UserProfile? matchingUser = _databaseService.findMatchingUser(
        faceEmbedding,
      );

      // Show a success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              matchingUser != null
                  ? 'Welcome back, ${matchingUser.name}!'
                  : 'Liveness check successful!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        if (matchingUser != null) {
          // --- User Found ---
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProfilePage(user: matchingUser),
            ),
          );
        } else {
          // --- New User ---
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  RegistrationPage(faceEmbedding: faceEmbedding),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during processing: $e');
      _showErrorSnackbar(
        'An error occurred during processing. Please try again.',
      );

      // Reset the state to allow retrying
      if (mounted) {
        setState(() {
          _currentStep = LivenessStep.initial;
          _instructionText = 'Please look at the camera';
          _isDetecting = false;
        });
        // Re-initialize detector and stream
        _initializeCamera();
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null || _frontCamera == null) return null;

    final sensorOrientation = _frontCamera!.sensorOrientation;
    InputImageRotation rotation;

    if (Platform.isIOS) {
      rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

      final deviceOrientation = _deviceOrientation;
      final rotationCompensation = orientations[deviceOrientation];

      if (rotationCompensation == null) {
        _isDetecting = false;
        return null;
      }

      final compensatedRotation =
          (sensorOrientation + rotationCompensation) % 360;

      rotation =
          InputImageRotationValue.fromRawValue(compensatedRotation) ??
          InputImageRotation.rotation0deg;
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [_buildCameraPreview(), _buildInstructionOverlay()],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildInstructionOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          color: Colors.black.withValues(alpha: 0.5),
          child: Text(
            'Liveness Check',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(),
        // Face outline
        Container(
          width: 280,
          height: 380,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2.0),
            shape: BoxShape.rectangle,
            borderRadius: const BorderRadius.all(Radius.circular(150)),
            color: Colors.transparent,
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          color: Colors.black.withValues(alpha: 0.5),
          child: _buildInstructionView(),
        ),
      ],
    );
  }

  Widget _buildInstructionView() {
    return Text(
      _instructionText,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: Text('Camera not initialized'));
    }

    final size = MediaQuery.of(context).size;
    // Calculate the scale to fill the screen while maintaining the aspect ratio
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(child: CameraPreview(_controller!)),
    );
  }
}
