import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Register
  Future<bool> register({
  required String name,
  required String email,
  required String password,
  required File faceImage,
  required String region,
  required String district,
  required String subDistrict,
  required String stoName,
}) async {
  _setLoading(true);
  _errorMessage = null;

  final result = await _authService.register(
    name: name,
    email: email,
    password: password,
    faceImage: faceImage,
    region: region,
    district: district,
    subDistrict: subDistrict,
    stoName: stoName,
  );

  _setLoading(false);

  if (result['success']) {
    return true;
  } else {
    _errorMessage = result['message'];
    notifyListeners();
    return false;
  }
}

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _authService.login(
      email: email,
      password: password,
    );

    _setLoading(false);

    if (result['success']) {
      _user = result['data']['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.deleteToken();
    _user = null;
    notifyListeners();
  }
}