class ApiConstants {
  // Ganti dengan IP komputer kamu saat testing di HP fisik
  // Kalau pakai emulator Android, gunakan 10.0.2.2
  // static const String baseUrl = 'http://192.168.100.21:3000/api';
  static const String baseUrl = 'http://192.168.1.8:3000/api';
  static const String faceLogin = '$baseUrl/face-login';

  static const String register = '$baseUrl/register';
  static const String login = '$baseUrl/login';
  static const String profile = '$baseUrl/profile';
  static const String checkIn = '$baseUrl/attendance/checkin';
  static const String checkOut = '$baseUrl/attendance/checkout';
  static const String history = '$baseUrl/attendance/history';
}