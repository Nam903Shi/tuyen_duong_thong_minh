import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trang_chu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hệ Thống Quản Trị - Phường Bình Minh',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      debugShowCheckedModeBanner: false,
      home: const ManHinhDangNhapCanBo(),
    );
  }
}

class ManHinhDangNhapCanBo extends StatefulWidget {
  const ManHinhDangNhapCanBo({super.key});
  @override
  State<ManHinhDangNhapCanBo> createState() => _ManHinhDangNhapCanBoState();
}

class _ManHinhDangNhapCanBoState extends State<ManHinhDangNhapCanBo> {
  final _taiKhoanCtrl = TextEditingController();
  final _matKhauCtrl = TextEditingController();
  bool _dangXuLy = false;
  bool _hienMatKhau = false;

  Future<void> _xuLyDangNhap() async {
    if (_taiKhoanCtrl.text.isEmpty || _matKhauCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin!')));
      return;
    }
    setState(() => _dangXuLy = true);
    try {
      String taiKhoan = _taiKhoanCtrl.text.trim();
      // Tự động ghép đuôi nội bộ nếu cán bộ chỉ nhập SĐT
      if (!taiKhoan.contains('@')) {
        taiKhoan = '$taiKhoan@binhminh.vn';
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: taiKhoan,
        password: _matKhauCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const TrangChu()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tài khoản hoặc mật khẩu không đúng!'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Phường
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Image.asset('assets/logo.jpg',
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.shield,
                              size: 80, color: Colors.green))),
                ),
                const SizedBox(height: 24),
                const Text('CỔNG ĐIỀU HÀNH NỘI BỘ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('HỆ THỐNG QUẢN LÝ TUYẾN ĐƯỜNG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const Text('UBND PHƯỜNG BÌNH MINH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                const SizedBox(height: 40),

                // Form Đăng Nhập
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng nhập hệ thống',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 20),
                      TextField(
                          controller: _taiKhoanCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại cán bộ',
                            prefixIcon:
                                const Icon(Icons.person, color: Colors.green),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2)),
                          )),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _matKhauCtrl,
                          obscureText: !_hienMatKhau,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon:
                                const Icon(Icons.lock, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _hienMatKhau
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey),
                              onPressed: () =>
                                  setState(() => _hienMatKhau = !_hienMatKhau),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2)),
                          )),
                      const SizedBox(height: 30),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                              onPressed: _dangXuLy ? null : _xuLyDangNhap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: _dangXuLy
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('ĐĂNG NHẬP',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)))),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('Phiên bản quản trị nội bộ v1.0',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
