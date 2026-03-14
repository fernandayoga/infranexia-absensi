import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  // Simpan token ke local storage
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Ambil token dari local storage
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Hapus token saat logout
  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // Register dengan foto wajah
Future<Map<String, dynamic>> register({
  required String name,
  required String email,
  required String password,
  required File faceImage,
  required String region,
  required String district,
  required String subDistrict,
  required String stoName,
}) async {
  try {
    final formData = FormData.fromMap({
      'name': name,
      'email': email,
      'password': password,
      'region': region,
      'district': district,
      'sub_district': subDistrict,
      'sto_name': stoName,
      'face_image': await MultipartFile.fromFile(
        faceImage.path,
        filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final response = await _dio.post(
      ApiConstants.register,
      data: formData,
    );

    return {'success': true, 'data': response.data};
  } on DioException catch (e) {
    print('=== REGISTER ERROR ===');
    print('Status code: ${e.response?.statusCode}');
    print('Response data: ${e.response?.data}');
    print('Error type: ${e.type}');
    final message = e.response?.data['message'] ?? 'Terjadi kesalahan';
    return {'success': false, 'message': message};
  }
}

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      // Simpan token otomatis setelah login
      final token = response.data['token'];
      await saveToken(token);

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan';
      return {'success': false, 'message': message};
    }
  }
}
