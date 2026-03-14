import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableContours: false,
      enableTracking: false,
      minFaceSize: 0.3, // wajah minimal 30% dari gambar
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Deteksi wajah dari file gambar
  Future<FaceDetectionResult> detectFace(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceDetectionResult(
          success: false,
          message: 'Tidak ada wajah terdeteksi. Pastikan wajah kamu terlihat jelas.',
        );
      }

      if (faces.length > 1) {
        return FaceDetectionResult(
          success: false,
          message: 'Terdeteksi lebih dari satu wajah. Pastikan hanya ada satu wajah.',
        );
      }

      return FaceDetectionResult(
        success: true,
        message: 'Wajah terdeteksi!',
        faceCount: faces.length,
      );
    } catch (e) {
      return FaceDetectionResult(
        success: false,
        message: 'Gagal mendeteksi wajah. Coba lagi.',
      );
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

class FaceDetectionResult {
  final bool success;
  final String message;
  final int faceCount;

  FaceDetectionResult({
    required this.success,
    required this.message,
    this.faceCount = 0,
  });
}