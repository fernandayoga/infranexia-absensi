import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../../shared/widgets/sto_dropdown.dart';
import '../../../core/services/face_detector_service.dart';
import '../../../shared/widgets/liveness_detection_screen.dart';
import 'package:image/image.dart' as img_lib;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final FaceDetectorService _faceDetectorService = FaceDetectorService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isDetectingFace = false;
  File? _faceImage;

  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedSubDistrict;
  String? _selectedSto;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  Future<void> _pickFaceImage() async {
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => const LivenessDetectionScreen(),
      ),
    );

    if (result == null) return;

    setState(() => _isDetectingFace = true);

    // ===== VALIDASI DI FLUTTER =====
    final bytes = await result.readAsBytes();
    final decodedImage = img_lib.decodeImage(bytes);

    if (decodedImage == null) {
      setState(() => _isDetectingFace = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Gagal membaca foto, coba lagi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    
    // Cek kecerahan - cara lebih cepat
    final grayscale = img_lib.grayscale(decodedImage);
    double brightness = 0;
    int sampleSize = 100; // sample 100 pixel saja, tidak perlu semua
    final stepX = decodedImage.width ~/ 10;
    final stepY = decodedImage.height ~/ 10;

    for (int y = 0; y < decodedImage.height; y += stepY) {
      for (int x = 0; x < decodedImage.width; x += stepX) {
        final pixel = grayscale.getPixel(x, y);
        brightness += pixel.r;
      }
    }
    brightness /= sampleSize;

    if (brightness < 60) {
      setState(() => _isDetectingFace = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Foto terlalu gelap, cari tempat lebih terang'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (brightness > 220) {
      setState(() => _isDetectingFace = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Foto terlalu terang, hindari cahaya langsung'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cek wajah dengan ML Kit
    final faceResult = await _faceDetectorService.detectFace(result);

    setState(() => _isDetectingFace = false);

    if (!mounted) return;

    if (!faceResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${faceResult.message}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Semua validasi passed
    setState(() => _faceImage = result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Foto wajah valid!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto wajah wajib diambil'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedSto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih STO Terdekat terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      faceImage: _faceImage!,
      region: _selectedRegion!,
      district: _selectedDistrict!,
      subDistrict: _selectedSubDistrict!,
      stoName: _selectedSto!,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Registrasi gagal'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  InputDecoration _inputDecorationWithToggle(
      String hint, bool obscure, VoidCallback onToggle) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.black45,
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/LogoPanjang.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Silahkan daftar menggunakan email pekerjaan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),

              const SizedBox(height: 24),

              // ===== FOTO WAJAH =====
              Center(
                child: GestureDetector(
                  onTap: _isDetectingFace ? null : _pickFaceImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _faceImage != null
                            ? const Color.fromARGB(255, 98, 219, 110)
                            : const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                    ),
                    child: _isDetectingFace
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color.fromARGB(255, 98, 219, 110),
                              strokeWidth: 2,
                            ),
                          )
                        : _faceImage != null
                            ? ClipOval(
                                child: Image.file(
                                  _faceImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined,
                                      size: 30, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text(
                                    'Foto Wajah',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),

              if (_faceImage != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _isDetectingFace ? null : _pickFaceImage,
                    icon: const Icon(Icons.refresh,
                        size: 14, color: Color.fromARGB(255, 98, 219, 110)),
                    label: const Text(
                      'Ambil ulang',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 98, 219, 110)),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ===== NAMA =====
              _fieldLabel('Nama'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Masukan Nama'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),

              const SizedBox(height: 16),

              // ===== EMAIL =====
              _fieldLabel('Email'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Masukan email atau nomor hp'),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!v.contains('@')) return 'Email tidak valid';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ===== PASSWORD =====
              _fieldLabel('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecorationWithToggle(
                  'Masukan password',
                  _obscurePassword,
                  () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Password tidak boleh kosong';
                  }
                  if (v.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ===== KONFIRMASI PASSWORD =====
              _fieldLabel('Konfirmasi Password'),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: _inputDecorationWithToggle(
                  'Masukan password kembali',
                  _obscureConfirmPassword,
                  () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Konfirmasi password tidak boleh kosong';
                  }
                  if (v != _passwordController.text) {
                    return 'Password tidak sama';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ===== LOKASI STO =====
              _fieldLabel('Lokasi STO'),
              StoDropdown(
                onChanged: (region, district, subDistrict, stoName) {
                  setState(() {
                    _selectedRegion = region;
                    _selectedDistrict = district;
                    _selectedSubDistrict = subDistrict;
                    _selectedSto = stoName;
                  });
                },
              ),

              const SizedBox(height: 32),

              // ===== TOMBOL DAFTAR =====
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Daftar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== LINK LOGIN =====
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Sudah punya akun? ',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Color(0xFFCC0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
