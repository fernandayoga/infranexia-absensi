import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:typed_data';

enum LivenessStep { front, right, left, done }

class LivenessDetectionScreen extends StatefulWidget {
  const LivenessDetectionScreen({super.key});

  @override
  State<LivenessDetectionScreen> createState() =>
      _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  LivenessStep _currentStep = LivenessStep.front;
  bool _isProcessing = false;
  bool _stepCompleted = false;
  String _instruction = 'Hadapkan wajah ke depan';
  String _stepIndicator = '1 / 3';

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initFaceDetector();
  }

  void _initFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.3,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() {});
    _startImageStream();
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing || _currentStep == LivenessStep.done) return;
      _isProcessing = true;

      try {
        final faces = await _detectFacesFromStream(image);
        if (faces.isNotEmpty) {
          final face = faces.first;
          final angleY = face.headEulerAngleY ?? 0;

          _checkLivenessStep(angleY);
        }
      } catch (e) {
        // ignore stream errors
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<List<Face>> _detectFacesFromStream(CameraImage image) async {
    final camera = _cameraController!.description;

    final inputImage = InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationFromCamera(camera.sensorOrientation),
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    return await _faceDetector!.processImage(inputImage);
  }

  InputImageRotation _rotationFromCamera(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _checkLivenessStep(double angleY) {
    bool conditionMet = false;

    switch (_currentStep) {
      case LivenessStep.front:
        conditionMet = angleY.abs() < 10; // hadap depan
        break;
      case LivenessStep.right:
        conditionMet = angleY < -20; // hadap kanan
        break;
      case LivenessStep.left:
        conditionMet = angleY > 20; // hadap kiri
        break;
      default:
        break;
    }

    if (conditionMet && !_stepCompleted) {
      setState(() => _stepCompleted = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        _nextStep(); // sudah async, tidak perlu await di sini
      });
    }
  }

  Future<void> _nextStep() async {
    setState(() {
      _stepCompleted = false;
      switch (_currentStep) {
        case LivenessStep.front:
          _currentStep = LivenessStep.right;
          _instruction = 'Hadapkan wajah ke kanan';
          _stepIndicator = '2 / 3';
          break;
        case LivenessStep.right:
          _currentStep = LivenessStep.left;
          _instruction = 'Hadapkan wajah ke kiri';
          _stepIndicator = '3 / 3';
          break;
        case LivenessStep.left:
          _currentStep = LivenessStep.done;
          _instruction = 'Liveness berhasil!';
          _stepIndicator = '✓';
          break;
        default:
          break;
      }
    });

    // Ambil foto saat step depan selesai
    if (_currentStep == LivenessStep.right) {
      await _capturePhoto();
    }

    // Pop setelah step kiri selesai
    if (_currentStep == LivenessStep.done) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, _capturedPhoto);
    }
  }

  File? _capturedPhoto;

  Future<void> _capturePhoto() async {
    try {
      final photo = await _cameraController!.takePicture();
      _capturedPhoto = File(photo.path);
    } catch (e) {
      // ignore
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = planes.map((p) => p.bytes).toList();
    final totalLength = allBytes.fold<int>(0, (sum, b) => sum + b.length);
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final bytes in allBytes) {
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }
    return result;
  }

  Color get _stepColor {
    if (_stepCompleted) return Colors.green;
    return const Color(0xFFCC0000);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== KAMERA =====
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // ===== OVERLAY LINGKARAN =====
          // ===== OVERLAY LINGKARAN =====
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceOvalPainter(
                borderColor: _stepCompleted
                    ? Colors.green
                    : _currentStep == LivenessStep.done
                        ? Colors.green
                        : Colors.white,
              ),
            ),
          ),

          // ===== INSTRUKSI ATAS =====
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _stepIndicator,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== INDIKATOR STEP =====
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepDot(LivenessStep.front, '↑'),
                const SizedBox(width: 16),
                _buildStepDot(LivenessStep.right, '→'),
                const SizedBox(width: 16),
                _buildStepDot(LivenessStep.left, '←'),
              ],
            ),
          ),

          // ===== TOMBOL BATAL =====
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context, null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(LivenessStep step, String icon) {
    final isCompleted = step.index < _currentStep.index;
    final isCurrent = step == _currentStep;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isCurrent
                ? _stepColor
                : Colors.white24,
        border: Border.all(
          color: isCurrent ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                icon,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}

// ===== OVAL PAINTER =====
class _FaceOvalPainter extends CustomPainter {
  final Color borderColor;

  _FaceOvalPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: size.width * 0.7,
      height: size.height * 0.45,
    );

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Border oval — warnanya dinamis
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceOvalPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}
