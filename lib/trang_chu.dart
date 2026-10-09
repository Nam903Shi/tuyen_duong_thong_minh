import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'main.dart';

class TrangChu extends StatefulWidget {
  const TrangChu({super.key});

  @override
  State<TrangChu> createState() => _TrangChuState();
}

class _TrangChuState extends State<TrangChu> {
  int _selectedIndex = 0;
  String _tuKhoaTimKiem = '';
  bool _laBanDoVeTinh = false;

  final MapController _mapController = MapController();
  final TextEditingController _timKiemBanDoCtrl = TextEditingController();

  final LatLng _toaDoBinhMinh = const LatLng(11.3650, 106.1280);
  LatLng? _toaDoDangChon;
  LatLng? _toaDoTimKiem;

  final List<String> _ds10KhuPho = [
    'Bình Trung',
    'Giồng Cà',
    'Ninh Lộc',
    'Ninh Phú',
    'Ninh Thọ',
    'Ninh Trung',
    'Tân Hòa',
    'Tân Phước',
    'Thạnh Đông',
    'Thạnh Hiệp'
  ];

  final Map<String, LatLng> _duLieuDiaDiem = {
    '10': const LatLng(11.3610, 106.1265),
    '40': const LatLng(11.3645, 106.1278),
    '100': const LatLng(11.3680, 106.1292),
    'bo to moc tien': const LatLng(11.3662, 106.1285),
    'cho ninh son': const LatLng(11.3392, 106.1362),
    'ubnd phuong binh minh': const LatLng(11.3650, 106.1280),
    'cafe': const LatLng(11.3652, 106.1270),
  };

  String _boDauTiengViet(String str) {
    str = str.toLowerCase();
    str = str.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    return str;
  }

  void _xuLyTimKiemBanDoAdmin(String tuKhoa) {
    FocusScope.of(context).unfocus();
    if (tuKhoa.trim().isEmpty) return;

    String queryKhongDau = _boDauTiengViet(tuKhoa.trim());
    LatLng? ketQuaToaDo;

    _duLieuDiaDiem.forEach((key, latLng) {
      if (queryKhongDau.contains(key) || key.contains(queryKhongDau)) {
        ketQuaToaDo = latLng;
      }
    });

    if (ketQuaToaDo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Không tìm thấy "$tuKhoa" trên bản đồ!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _toaDoTimKiem = ketQuaToaDo;
    });
    _mapController.move(ketQuaToaDo!, 17.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Đã định vị đến: $tuKhoa'),
          backgroundColor: Colors.green),
    );
  }

  void _xacNhanDangXuat() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text(
              'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống không?'),
          actions: <Widget>[
            TextButton(
                child: const Text('Hủy'),
                onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Đăng xuất'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ManHinhDangNhap()));
                }
              },
            ),
          ],
        );
      },
    );
  }

  LatLng? _phanTichToaDo(dynamic rawToaDo) {
    if (rawToaDo == null) return null;
    String str = rawToaDo.toString().trim();
    if (str.isEmpty || !str.contains(',')) return null;
    try {
      List<String> parts = str.split(',');
      double lat = double.parse(parts[0].trim());
      double lng = double.parse(parts[1].trim());
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Widget _hienThiHinhAnh(String duongDanHoacBase64) {
    if (duongDanHoacBase64.startsWith('http://') ||
        duongDanHoacBase64.startsWith('https://')) {
      return Image.network(
        duongDanHoacBase64,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Text('Không thể tải ảnh'))),
      );
    } else {
      try {
        String cleanBase64 = duongDanHoacBase64;
        if (cleanBase64.contains(',')) cleanBase64 = cleanBase64.split(',')[1];
        return Image.memory(
          base64Decode(cleanBase64),
          height: 240,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
              height: 120,
              color: Colors.grey.shade200,
              child: const Center(child: Text('Lỗi hiển thị'))),
        );
      } catch (_) {
        File f = File(duongDanHoacBase64);
        if (f.existsSync())
          return Image.file(f,
              height: 240, width: double.infinity, fit: BoxFit.cover);
        return Container(
            height: 120,
            color: Colors.grey.shade200,
            child: const Center(child: Text('Không tìm thấy ảnh')));
      }
    }
  }

  void _xemChiTietSuCo(Map<String, dynamic> pa) {
    bool daXuLy = pa['trang_thai'] == 'Đã xử lý';
    String? anhBaoCao = pa['anh_ket_qua'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(daXuLy ? Icons.check_circle : Icons.warning_amber_rounded,
                color: daXuLy ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Expanded(
                child: Text(daXuLy ? 'Kết quả xử lý' : 'Chi tiết sự cố',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nội dung: ${pa['noi_dung'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Text('📍 Vị trí: ${pa['vi_tri'] ?? ''}'),
                Text('🧭 Tọa độ: ${pa['toa_do'] ?? ''}'),
                Text(
                    'Phân loại: ${pa['phan_loai'] ?? ''} | Mức độ: ${pa['muc_do'] ?? ''}'),
                Text(
                    'Người báo: ${pa['nguoi_bao'] ?? 'Không rõ'} - Ngày: ${pa['ngay_bao'] ?? ''}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Trạng thái: '),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: daXuLy
                            ? Colors.green
                            : (pa['trang_thai'] == 'Đang xử lý'
                                ? Colors.orange
                                : Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(pa['trang_thai'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                if (daXuLy) ...[
                  const Divider(height: 24, thickness: 1.2),
                  const Text('✅ KẾT QUẢ HIỆN TRƯỜNG:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Khắc phục: ${pa['noi_dung_xu_ly'] ?? 'Đã hoàn thành'}',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  if (anhBaoCao != null && anhBaoCao.isNotEmpty)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _hienThiHinhAnh(anhBaoCao))
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'))
        ],
      ),
    );
  }

  void _hienThiDanhSachCanXuLy(List<QueryDocumentSnapshot> danhSachDocs) {
    final dsCanXuLy = danhSachDocs.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      return (d['trang_thai'] ?? 'Chưa xử lý') == 'Chưa xử lý';
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Cần xử lý (${dsCanXuLy.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: dsCanXuLy.isEmpty
              ? const Center(
                  child: Text('Không có sự cố nào tồn đọng!',
                      style: TextStyle(color: Colors.green, fontSize: 16)))
              : ListView.separated(
                  itemCount: dsCanXuLy.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    var pa = dsCanXuLy[i].data() as Map<String, dynamic>;
                    LatLng? toaDo = _phanTichToaDo(pa['toa_do']);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 0),
                      leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.report,
                              color: Colors.white, size: 18)),
                      title: Text(pa['noi_dung'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('📍 ${pa['vi_tri'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.near_me, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedIndex = 0);
                          if (toaDo != null) {
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              _mapController.move(toaDo, 16.5);
                              _xemChiTietSuCo(pa);
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
        ],
      ),
    );
  }

  void _hienThiDanhSachDaXuLy(List<QueryDocumentSnapshot> danhSachDocs) {
    final dsDaXuLy = danhSachDocs.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      return (d['trang_thai'] ?? '') == 'Đã xử lý';
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text('Đã hoàn thành (${dsDaXuLy.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: dsDaXuLy.isEmpty
              ? const Center(
                  child: Text('Chưa có sự cố nào hoàn thành.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: dsDaXuLy.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    var pa = dsDaXuLy[i].data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 0),
                      leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child:
                              Icon(Icons.check, color: Colors.white, size: 18)),
                      title: Text(pa['noi_dung'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('✅ ${pa['noi_dung_xu_ly'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_red_eye,
                            color: Colors.green),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _xemChiTietSuCo(pa);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
        ],
      ),
    );
  }

  void _chonKhuPhoDeXuatExcelNhanKhau() {
    String khuPhoDaChon = 'Tất cả';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('Xuất dữ liệu Nhân khẩu',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn khu phố cần xuất báo cáo:',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: khuPhoDaChon,
                      isExpanded: true,
                      items: ['Tất cả', ..._ds10KhuPho]
                          .map((kp) => DropdownMenuItem(
                              value: kp,
                              child: Text(kp == 'Tất cả'
                                  ? 'Tất cả Khu phố'
                                  : 'Khu phố $kp')))
                          .toList(),
                      onChanged: (v) => setStateSB(() => khuPhoDaChon = v!),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      const Text('Hủy', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Xuất file'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _xuatExcelNhanKhau(khuPhoDaChon);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _xuatExcelNhanKhau(String khuPho) async {
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(
              child: CircularProgressIndicator(color: Colors.green)));
      Query query = FirebaseFirestore.instance
          .collection('nhan_khau')
          .orderBy('la_chu_ho', descending: true);
      if (khuPho != 'Tất cả')
        query = FirebaseFirestore.instance
            .collection('nhan_khau')
            .where('khu_pho', isEqualTo: khuPho);
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Không có dữ liệu cho khu phố $khuPho!'),
            backgroundColor: Colors.orange));
        return;
      }
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['NhanKhau'];
      excel.delete('Sheet1');
      sheetObject.appendRow([
        TextCellValue('STT'),
        TextCellValue('Họ và tên'),
        TextCellValue('Vai trò'),
        TextCellValue('Ngày sinh'),
        TextCellValue('Giới tính'),
        TextCellValue('CCCD'),
        TextCellValue('SĐT'),
        TextCellValue('Số nhà'),
        TextCellValue('Khu phố'),
        TextCellValue('Vị trí chi tiết'),
      ]);
      int stt = 1;
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        sheetObject.appendRow([
          IntCellValue(stt++),
          TextCellValue(data['ho_ten'] ?? ''),
          TextCellValue((data['la_chu_ho'] ?? false) ? 'Chủ hộ' : 'Thành viên'),
          TextCellValue(data['ngay_sinh'] ?? ''),
          TextCellValue(data['gioi_tinh'] ?? ''),
          TextCellValue(data['cccd'] ?? ''),
          TextCellValue(data['sdt'] ?? ''),
          TextCellValue(data['so_nha'] ?? ''),
          TextCellValue(data['khu_pho'] ?? ''),
          TextCellValue(data['vi_tri'] ?? ''),
        ]);
      }
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String tenFile = khuPho == 'Tất cả' ? 'ToanPhuong' : 'KP_$khuPho';
      tenFile = _boDauTiengViet(tenFile).replaceAll(' ', '_');
      String filePath =
          '${appDocDir.path}/DS_Nhan_Khau_${tenFile}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Xuất file thành công!\n$filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _xuatExcelPhanAnh() async {
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(
              child: CircularProgressIndicator(color: Colors.orange)));
      final snapshot = await FirebaseFirestore.instance
          .collection('phan_anh')
          .orderBy('ngay_bao', descending: true)
          .get();
      if (snapshot.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có phản ánh nào!')));
        return;
      }
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['PhanAnhSuCo'];
      excel.delete('Sheet1');
      sheetObject.appendRow([
        TextCellValue('STT'),
        TextCellValue('Nội dung sự cố'),
        TextCellValue('Vị trí'),
        TextCellValue('Tọa độ GPS'),
        TextCellValue('Phân loại'),
        TextCellValue('Mức độ'),
        TextCellValue('Người báo tin / SĐT'),
        TextCellValue('Trạng thái'),
        TextCellValue('Ngày báo'),
        TextCellValue('Kết quả xử lý'),
      ]);
      int stt = 1;
      for (var doc in snapshot.docs) {
        var data = doc.data();
        sheetObject.appendRow([
          IntCellValue(stt++),
          TextCellValue(data['noi_dung'] ?? ''),
          TextCellValue(data['vi_tri'] ?? ''),
          TextCellValue(data['toa_do'] ?? ''),
          TextCellValue(data['phan_loai'] ?? ''),
          TextCellValue(data['muc_do'] ?? ''),
          TextCellValue(data['nguoi_bao'] ?? ''),
          TextCellValue(data['trang_thai'] ?? ''),
          TextCellValue(data['ngay_bao'] ?? ''),
          TextCellValue(data['noi_dung_xu_ly'] ?? ''),
        ]);
      }
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String filePath =
          '${appDocDir.path}/Danh_Sach_Phan_Anh_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Xuất file thành công!\n$filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Biến nhận diện thiết bị: Nếu màn hình hẹp hơn 600px thì là Mobile
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (!isMobile) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/logo.jpg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.location_city,
                        color: Colors.white,
                        size: 28)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                isMobile
                    ? 'Quản Lý Tuyến Đường'
                    : 'Hệ Thống Quản Lý Tuyến Đường - Phường Bình Minh',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18),
                overflow: TextOverflow.ellipsis, // Cắt chữ thừa nếu quá dài
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: isMobile
                ? IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Đăng xuất',
                    onPressed: _xacNhanDangXuat,
                  )
                : TextButton.icon(
                    onPressed: _xacNhanDangXuat,
                    icon:
                        const Icon(Icons.logout, color: Colors.white, size: 18),
                    label: const Text('Đăng xuất',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                  ),
          ),
        ],
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isMobile
          ? _hienThiNoiDung(_selectedIndex, isMobile)
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) => setState(() {
                    _selectedIndex = index;
                    _tuKhoaTimKiem = '';
                  }),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme:
                      const IconThemeData(color: Colors.green, size: 30),
                  selectedLabelTextStyle: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: Text('Bản đồ')),
                    NavigationRailDestination(
                        icon: Icon(Icons.family_restroom_outlined),
                        selectedIcon: Icon(Icons.family_restroom),
                        label: Text('Nhân khẩu')),
                    NavigationRailDestination(
                        icon: Icon(Icons.report_problem_outlined),
                        selectedIcon: Icon(Icons.report_problem),
                        label: Text('Phản ánh')),
                    NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Hệ thống')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                    child: Container(
                        color: Colors.grey[100],
                        child: _hienThiNoiDung(_selectedIndex, isMobile)))
              ],
            ),
      // Khi ở Mobile thì hiện Menu ngang phía dưới
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (int index) => setState(() {
                _selectedIndex = index;
                _tuKhoaTimKiem = '';
              }),
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Bản đồ'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.family_restroom), label: 'Nhân khẩu'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.report_problem), label: 'Phản ánh'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Hệ thống'),
              ],
            )
          : null,
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const FormThemNhanKhau()),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhân khẩu'),
            )
          : _selectedIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const FormThemPhanAnh()),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_alert),
                  label: const Text('Tạo phản ánh'),
                )
              : null,
    );
  }

  void _xacNhanXoaNhanKhau(
      BuildContext context, String documentId, String hoTen) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Xóa hồ sơ của "$hoTen"?'),
        actions: [
          TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(dialogContext).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa ngay'),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('nhan_khau')
                  .doc(documentId)
                  .delete();
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  void _xacNhanXoaPhanAnh(BuildContext context, String documentId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Xóa phản ánh',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn xóa không?'),
        actions: [
          TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(dialogContext).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('phan_anh')
                  .doc(documentId)
                  .delete();
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _hienThiNoiDung(int index, bool isMobile) {
    if (index == 0) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('phan_anh').snapshots(),
        builder: (context, paSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('nhan_khau').snapshots(),
            builder: (context, nkSnapshot) {
              List<Marker> danhSachGhim = [
                Marker(
                    point: _toaDoBinhMinh,
                    width: 40,
                    height: 40,
                    child: const Tooltip(
                        message: 'UBND Phường Bình Minh',
                        child: Icon(Icons.account_balance,
                            color: Colors.indigo, size: 30))),
              ];

              int chuaXuLy = 0, dangXuLy = 0, daXuLy = 0;
              if (paSnapshot.hasData) {
                for (var doc in paSnapshot.data!.docs) {
                  var pa = doc.data() as Map<String, dynamic>;
                  String tt = pa['trang_thai'] ?? 'Chưa xử lý';
                  if (tt == 'Đang xử lý')
                    dangXuLy++;
                  else if (tt == 'Đã xử lý')
                    daXuLy++;
                  else
                    chuaXuLy++;

                  LatLng? toaDo = _phanTichToaDo(pa['toa_do']);
                  if (toaDo != null) {
                    Color mauGhim = tt == 'Đang xử lý'
                        ? Colors.orange
                        : (tt == 'Đã xử lý' ? Colors.green : Colors.red);
                    danhSachGhim.add(Marker(
                      point: toaDo,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _xemChiTietSuCo(pa),
                        child:
                            Icon(Icons.location_on, color: mauGhim, size: 36),
                      ),
                    ));
                  }
                }
              }

              int tongNhanKhau =
                  nkSnapshot.hasData ? nkSnapshot.data!.docs.length : 0;
              int tongChuHo = 0;
              if (nkSnapshot.hasData) {
                for (var doc in nkSnapshot.data!.docs) {
                  if ((doc.data() as Map<String, dynamic>)['la_chu_ho'] == true)
                    tongChuHo++;
                }
              }

              if (_toaDoDangChon != null)
                danhSachGhim.add(Marker(
                    point: _toaDoDangChon!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.pin_drop,
                        color: Colors.purpleAccent, size: 40)));
              if (_toaDoTimKiem != null)
                danhSachGhim.add(Marker(
                    point: _toaDoTimKiem!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.pin_drop,
                        color: Colors.redAccent, size: 42)));

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _toaDoBinhMinh,
                      initialZoom: 14.5,
                      onTap: (tapPosition, latLng) =>
                          setState(() => _toaDoDangChon = latLng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _laBanDoVeTinh
                            ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                            : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      ),
                      MarkerLayer(markers: danhSachGhim),
                    ],
                  ),

                  // LỚP OVERLAY TRÊN BẢN ĐỒ (Đã Responsive gọn gàng cho điện thoại)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Hàng 1: Thanh Tìm kiếm + Nút bản đồ
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search,
                                            color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _timKiemBanDoCtrl,
                                            decoration: const InputDecoration(
                                                hintText:
                                                    'Nhập tên địa điểm...',
                                                border: InputBorder.none,
                                                isDense: true),
                                            onSubmitted: (value) =>
                                                _xuLyTimKiemBanDoAdmin(value),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.my_location,
                                              color: Colors.blue, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _mapController.move(
                                              _toaDoBinhMinh, 14.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton.small(
                                heroTag: 'btn_doi_loai_map',
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                elevation: 4,
                                child: Icon(_laBanDoVeTinh
                                    ? Icons.map
                                    : Icons.satellite_alt),
                                onPressed: () => setState(
                                    () => _laBanDoVeTinh = !_laBanDoVeTinh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Hàng 2: Thanh hiển thị Thống Kê (Có thể trượt ngang nếu màn hình hẹp)
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Card(
                                  elevation: 4,
                                  color: Colors.white.withOpacity(0.95),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _itemTomTatNho(
                                            Icons.people,
                                            '$tongNhanKhau',
                                            'Nhân khẩu',
                                            Colors.blue,
                                            () => setState(
                                                () => _selectedIndex = 3)),
                                        _vachNganNho(),
                                        _itemTomTatNho(
                                            Icons.home,
                                            '$tongChuHo',
                                            'Hộ dân',
                                            Colors.teal,
                                            () => setState(
                                                () => _selectedIndex = 3)),
                                        _vachNganNho(),
                                        _itemTomTatNho(
                                            Icons.warning,
                                            '$chuaXuLy',
                                            'Cần xử lý',
                                            Colors.red, () {
                                          if (paSnapshot.hasData)
                                            _hienThiDanhSachCanXuLy(
                                                paSnapshot.data!.docs);
                                        }),
                                        _vachNganNho(),
                                        _itemTomTatNho(
                                            Icons.check_circle,
                                            '$daXuLy',
                                            'Đã xử lý',
                                            Colors.green, () {
                                          if (paSnapshot.hasData)
                                            _hienThiDanhSachDaXuLy(
                                                paSnapshot.data!.docs);
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  // Hộp chú thích trạng thái
                  Positioned(
                    bottom: 16,
                    left: 12,
                    child: SafeArea(
                      child: Card(
                        elevation: 4,
                        color: Colors.white.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Trạng thái sự cố',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.location_on,
                                    color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text('Chưa xử lý',
                                    style: TextStyle(fontSize: 11))
                              ]),
                              Row(children: [
                                Icon(Icons.location_on,
                                    color: Colors.orange, size: 16),
                                SizedBox(width: 4),
                                Text('Đang xử lý',
                                    style: TextStyle(fontSize: 11))
                              ]),
                              Row(children: [
                                Icon(Icons.location_on,
                                    color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text('Hoàn thành',
                                    style: TextStyle(fontSize: 11))
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Hộp tạo phản ánh khi click tọa độ
                  if (_toaDoDangChon != null)
                    Positioned(
                      bottom: 16,
                      right: 12,
                      child: SafeArea(
                        child: Card(
                          elevation: 6,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Colors.purpleAccent, width: 1.5)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Vị trí chọn:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.purple)),
                                    Text(
                                        '${_toaDoDangChon!.latitude.toStringAsFixed(4)}, ${_toaDoDangChon!.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                  onPressed: () {
                                    String toaDoStr =
                                        '${_toaDoDangChon!.latitude.toStringAsFixed(6)}, ${_toaDoDangChon!.longitude.toStringAsFixed(6)}';
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => FormThemPhanAnh(
                                            toaDoMacDinh: toaDoStr));
                                  },
                                  child: const Text('Tạo mới',
                                      style: TextStyle(fontSize: 12)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      setState(() => _toaDoDangChon = null),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
    }

    if (index == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nhân khẩu...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onChanged: (value) =>
                  setState(() => _tuKhoaTimKiem = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('nhan_khau')
                  .orderBy('la_chu_ho', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                      child: Text('Chưa có dữ liệu nhân khẩu.'));
                final danhSachDaLoc = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return (data['ho_ten'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_tuKhoaTimKiem) ||
                      (data['cccd'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_tuKhoaTimKiem);
                }).toList();
                if (danhSachDaLoc.isEmpty)
                  return const Center(child: Text('Không tìm thấy kết quả.'));

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 24, vertical: 8),
                  itemCount: danhSachDaLoc.length,
                  itemBuilder: (context, index) {
                    var nk =
                        danhSachDaLoc[index].data() as Map<String, dynamic>;
                    bool laChuHo = nk['la_chu_ho'] ?? false;
                    return Card(
                      elevation: laChuHo ? 4 : 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: laChuHo
                              ? const BorderSide(
                                  color: Colors.green, width: 1.2)
                              : BorderSide.none),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor:
                                laChuHo ? Colors.green : Colors.grey[300],
                            child: Icon(Icons.person,
                                color:
                                    laChuHo ? Colors.white : Colors.grey[700])),
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(nk['ho_ten'] ?? 'Chưa rõ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            if (laChuHo)
                              Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text('Chủ hộ',
                                          style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)))),
                          ],
                        ),
                        subtitle: Text(
                            'Sinh: ${nk['ngay_sinh']} | Giới: ${nk['gioi_tinh']}\nNhà số ${nk['so_nha']}, Tổ ${nk['to_dctq']}, KP ${nk['khu_pho']}',
                            style: TextStyle(
                                color: Colors.blueGrey[700], fontSize: 12)),
                        trailing: isMobile
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit_document,
                                          color: Colors.blue),
                                      onPressed: () => showDialog(
                                          context: context,
                                          builder: (c) => FormThemNhanKhau(
                                              documentId:
                                                  danhSachDaLoc[index].id,
                                              duLieuCu: nk))),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _xacNhanXoaNhanKhau(
                                          context,
                                          danhSachDaLoc[index].id,
                                          nk['ho_ten'])),
                                ],
                              ),
                        onTap: isMobile
                            ? () {
                                // Nếu ở màn hình nhỏ, click vào thẻ để sửa/xóa
                                showModalBottomSheet(
                                  context: context,
                                  builder: (c) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                            leading: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            title: const Text('Sửa thông tin'),
                                            onTap: () {
                                              Navigator.pop(c);
                                              showDialog(
                                                  context: context,
                                                  builder: (_) =>
                                                      FormThemNhanKhau(
                                                          documentId:
                                                              danhSachDaLoc[
                                                                      index]
                                                                  .id,
                                                          duLieuCu: nk));
                                            }),
                                        ListTile(
                                            leading: const Icon(Icons.delete,
                                                color: Colors.red),
                                            title: const Text('Xóa hồ sơ'),
                                            onTap: () {
                                              Navigator.pop(c);
                                              _xacNhanXoaNhanKhau(
                                                  context,
                                                  danhSachDaLoc[index].id,
                                                  nk['ho_ten']);
                                            }),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    if (index == 2) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('phan_anh')
            .orderBy('ngay_bao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text('Chưa có phản ánh sự cố nào.'));
          final danhSachPA = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            itemCount: danhSachPA.length,
            itemBuilder: (context, i) {
              String docId = danhSachPA[i].id;
              var pa = danhSachPA[i].data() as Map<String, dynamic>;
              Color mauTrangThai = pa['trang_thai'] == 'Đang xử lý'
                  ? Colors.orange
                  : (pa['trang_thai'] == 'Đã xử lý'
                      ? Colors.green
                      : Colors.red);
              IconData iconTrangThai = pa['trang_thai'] == 'Đang xử lý'
                  ? Icons.autorenew
                  : (pa['trang_thai'] == 'Đã xử lý'
                      ? Icons.check_circle
                      : Icons.error_outline);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: mauTrangThai.withOpacity(0.5), width: 1)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(iconTrangThai, color: mauTrangThai, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pa['noi_dung'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('📍 ${pa['vi_tri']}',
                                    style: const TextStyle(fontSize: 12)),
                                Text(
                                    'Người báo: ${pa['nguoi_bao']} - Ngày: ${pa['ngay_bao']}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: mauTrangThai,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(pa['trang_thai'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Cập nhật'),
                              onPressed: () => showDialog(
                                  context: context,
                                  builder: (c) => FormThemPhanAnh(
                                      documentId: docId, duLieuCu: pa))),
                          TextButton.icon(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 16),
                              label: const Text('Xóa',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () =>
                                  _xacNhanXoaPhanAnh(context, docId)),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (index == 3) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('nhan_khau').snapshots(),
        builder: (context, nkSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('phan_anh').snapshots(),
            builder: (context, paSnapshot) {
              int tongNK = 0, soChuHo = 0, nam = 0, nu = 0;
              Map<String, int> phanBoKP = {for (var kp in _ds10KhuPho) kp: 0};
              if (nkSnapshot.hasData) {
                tongNK = nkSnapshot.data!.docs.length;
                for (var doc in nkSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['la_chu_ho'] == true) soChuHo++;
                  if (data['gioi_tinh'] == 'Nam') nam++;
                  if (data['gioi_tinh'] == 'Nữ') nu++;
                  String kp = data['khu_pho'] ?? '';
                  for (var item in _ds10KhuPho) {
                    if (kp.contains(item)) {
                      phanBoKP[item] = (phanBoKP[item] ?? 0) + 1;
                      break;
                    }
                  }
                }
              }

              int chuaXL = 0, dangXL = 0, daXL = 0;
              if (paSnapshot.hasData) {
                for (var doc in paSnapshot.data!.docs) {
                  String tt =
                      (doc.data() as Map<String, dynamic>)['trang_thai'] ??
                          'Chưa xử lý';
                  if (tt == 'Đang xử lý')
                    dangXL++;
                  else if (tt == 'Đã xử lý')
                    daXL++;
                  else
                    chuaXL++;
                }
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16.0 : 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bảng Điều Hành Số Phường',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                    const SizedBox(height: 16),
                    // Responsive Thống kê tổng quan
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: _theChiSo(
                                'TỔNG NHÂN KHẨU',
                                '$tongNK',
                                'Nam: $nam | Nữ: $nu',
                                Icons.people,
                                Colors.blue,
                                null)),
                        SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: _theChiSo(
                                'HỘ GIA ĐÌNH',
                                '$soChuHo',
                                'Chủ hộ quản lý',
                                Icons.home,
                                Colors.teal,
                                null)),
                        SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: _theChiSo(
                                'SỰ CỐ CHƯA XỬ LÝ',
                                '$chuaXL',
                                'Nhấp để xem 📍',
                                Icons.warning_amber,
                                Colors.red, () {
                              if (paSnapshot.hasData)
                                _hienThiDanhSachCanXuLy(paSnapshot.data!.docs);
                            })),
                        SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: _theChiSo(
                                'ĐÃ GIẢI QUYẾT',
                                '$daXL',
                                'Nhấp xem kết quả 📸',
                                Icons.check_circle,
                                Colors.green, () {
                              if (paSnapshot.hasData)
                                _hienThiDanhSachDaXuLy(paSnapshot.data!.docs);
                            })),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Responsive Thống kê khu phố
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phân Bổ Theo 10 Khu Phố',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const Divider(height: 24),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: _ds10KhuPho.map((kp) {
                                int sl = phanBoKP[kp] ?? 0;
                                double tyLe = tongNK > 0 ? (sl / tongNK) : 0.0;
                                return Container(
                                  width: isMobile
                                      ? (MediaQuery.of(context).size.width -
                                              64) /
                                          2
                                      : 210, // Chia 2 cột trên điện thoại
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade200)),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('KP $kp',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('$sl dân',
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          Text(
                                              '${(tyLe * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                              value: tyLe,
                                              minHeight: 4,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              color: Colors.green))
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Responsive Xuất Excel
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                            width: isMobile ? double.infinity : 350,
                            child: _cardXuatExcel(
                                Icons.table_chart,
                                Colors.green,
                                'Xuất Dữ Liệu Nhân Khẩu',
                                'Theo từng Khu phố',
                                _chonKhuPhoDeXuatExcelNhanKhau)),
                        SizedBox(
                            width: isMobile ? double.infinity : 350,
                            child: _cardXuatExcel(
                                Icons.assignment,
                                Colors.orange,
                                'Xuất Phản Ánh Sự Cố',
                                'Lưu hồ sơ GPS hiện trường',
                                _xuatExcelPhanAnh)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
    return const Center(child: Text('Khu vực đang phát triển...'));
  }

  Widget _itemTomTatNho(IconData icon, String giaTri, String tieuDe, Color mau,
      VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: mau, size: 16),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(giaTri,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12, color: mau)),
                Text(tieuDe,
                    style: TextStyle(
                        fontSize: 9,
                        color: onTap != null
                            ? Colors.blue.shade900
                            : Colors.black54,
                        fontWeight: onTap != null
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vachNganNho() {
    return Container(
        height: 20,
        width: 1,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 6));
  }

  Widget _theChiSo(String tieuDe, String soLuong, String chuThich,
      IconData icon, Color mau, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: onTap != null
                ? BorderSide(color: mau.withOpacity(0.5), width: 1.2)
                : BorderSide.none),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: mau.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: mau, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tieuDe,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600)),
                    Text(soLuong,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: mau)),
                    Text(chuThich,
                        style: TextStyle(
                            fontSize: 10,
                            color: onTap != null ? mau : Colors.grey.shade600,
                            fontWeight: onTap != null
                                ? FontWeight.bold
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardXuatExcel(IconData icon, Color mau, String tieuDe, String phuDe,
      VoidCallback onPressed) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: mau.withOpacity(0.1),
                radius: 24,
                child: Icon(icon, color: mau, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(phuDe,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Xuất'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: mau,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
            )
          ],
        ),
      ),
    );
  }
}

// FORM PHẢN ÁNH
class FormThemPhanAnh extends StatefulWidget {
  final String? documentId;
  final Map<String, dynamic>? duLieuCu;
  final String? toaDoMacDinh;
  const FormThemPhanAnh(
      {super.key, this.documentId, this.duLieuCu, this.toaDoMacDinh});
  @override
  State<FormThemPhanAnh> createState() => _FormThemPhanAnhState();
}

class _FormThemPhanAnhState extends State<FormThemPhanAnh> {
  final _noiDungCtrl = TextEditingController(),
      _viTriCtrl = TextEditingController(),
      _toaDoCtrl = TextEditingController(),
      _nguoiBaoCtrl = TextEditingController(),
      _noiDungXuLyCtrl = TextEditingController(),
      _duongDanAnhCtrl = TextEditingController();
  String _phanLoai = 'Giao thông',
      _mucDo = 'Trung bình',
      _trangThai = 'Chưa xử lý';
  final _dsPhanLoai = [
        'Giao thông',
        'Vệ sinh môi trường',
        'An ninh trật tự',
        'Hạ tầng (điện, nước)',
        'Khác'
      ],
      _dsMucDo = ['Nhẹ', 'Trung bình', 'Nghiêm trọng'],
      _dsTrangThai = ['Chưa xử lý', 'Đang xử lý', 'Đã xử lý'];

  @override
  void initState() {
    super.initState();
    if (widget.duLieuCu != null) {
      _noiDungCtrl.text = widget.duLieuCu!['noi_dung'] ?? '';
      _viTriCtrl.text = widget.duLieuCu!['vi_tri'] ?? '';
      _toaDoCtrl.text = widget.duLieuCu!['toa_do'] ?? '';
      _nguoiBaoCtrl.text = widget.duLieuCu!['nguoi_bao'] ?? '';
      _noiDungXuLyCtrl.text = widget.duLieuCu!['noi_dung_xu_ly'] ?? '';
      _duongDanAnhCtrl.text = widget.duLieuCu!['anh_ket_qua'] ?? '';
      if (_dsPhanLoai.contains(widget.duLieuCu!['phanLoai']))
        _phanLoai = widget.duLieuCu!['phanLoai'];
      if (_dsMucDo.contains(widget.duLieuCu!['mucDo']))
        _mucDo = widget.duLieuCu!['mucDo'];
      if (_dsTrangThai.contains(widget.duLieuCu!['trang_thai']))
        _trangThai = widget.duLieuCu!['trang_thai'];
    } else if (widget.toaDoMacDinh != null)
      _toaDoCtrl.text = widget.toaDoMacDinh!;
  }

  @override
  Widget build(BuildContext context) {
    bool laCheDoSua = widget.documentId != null;
    return AlertDialog(
      title: Text(laCheDoSua ? 'Cập nhật' : 'Ghi nhận phản ánh',
          style: const TextStyle(
              color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _noiDungCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nội dung', prefixIcon: Icon(Icons.report)),
                  maxLines: 2),
              TextField(
                  controller: _viTriCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Vị trí',
                      prefixIcon: Icon(Icons.location_city))),
              TextField(
                  controller: _toaDoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'GPS', prefixIcon: Icon(Icons.gps_fixed))),
              DropdownButtonFormField<String>(
                  value: _phanLoai,
                  decoration: const InputDecoration(labelText: 'Phân loại'),
                  items: _dsPhanLoai
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _phanLoai = v!)),
              DropdownButtonFormField<String>(
                  value: _mucDo,
                  decoration: const InputDecoration(labelText: 'Mức độ'),
                  items: _dsMucDo
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _mucDo = v!)),
              TextField(
                  controller: _nguoiBaoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Người báo tin',
                      prefixIcon: Icon(Icons.person))),
              DropdownButtonFormField<String>(
                  value: _trangThai,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: _dsTrangThai
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _trangThai = v!)),
              if (_trangThai == 'Đã xử lý') ...[
                const Divider(height: 20, thickness: 1),
                TextField(
                    controller: _noiDungXuLyCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Kết quả xử lý',
                        prefixIcon: Icon(Icons.task_alt, color: Colors.green)),
                    maxLines: 2),
                TextField(
                    controller: _duongDanAnhCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Link ảnh kết quả',
                        prefixIcon: Icon(Icons.image, color: Colors.teal))),
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () async {
            DateTime now = DateTime.now();
            String ngayFormat =
                "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
            Map<String, dynamic> dl = {
              'noi_dung': _noiDungCtrl.text,
              'vi_tri': _viTriCtrl.text,
              'toa_do': _toaDoCtrl.text,
              'phan_loai': _phanLoai,
              'muc_do': _mucDo,
              'nguoi_bao': _nguoiBaoCtrl.text,
              'trang_thai': _trangThai,
              'noi_dung_xu_ly': _noiDungXuLyCtrl.text,
              'anh_ket_qua': _duongDanAnhCtrl.text.trim(),
              if (!laCheDoSua) 'ngay_bao': ngayFormat,
              if (_trangThai == 'Đã xử lý') 'ngay_hoan_thanh': ngayFormat,
            };
            laCheDoSua
                ? await FirebaseFirestore.instance
                    .collection('phan_anh')
                    .doc(widget.documentId)
                    .update(dl)
                : await FirebaseFirestore.instance
                    .collection('phan_anh')
                    .add(dl);
            if (mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: Text(laCheDoSua ? 'Cập nhật' : 'Tạo'),
        ),
      ],
    );
  }
}

// FORM NHÂN KHẨU
class FormThemNhanKhau extends StatefulWidget {
  final String? documentId;
  final Map<String, dynamic>? duLieuCu;
  const FormThemNhanKhau({super.key, this.documentId, this.duLieuCu});
  @override
  State<FormThemNhanKhau> createState() => _FormThemNhanKhauState();
}

class _FormThemNhanKhauState extends State<FormThemNhanKhau> {
  final _hoTenCtrl = TextEditingController(),
      _ngaySinhCtrl = TextEditingController(),
      _cccdCtrl = TextEditingController(),
      _sdtCtrl = TextEditingController(),
      _ngheNghiepCtrl = TextEditingController(),
      _soNhaCtrl = TextEditingController(),
      _toDCTQCtrl = TextEditingController(),
      _viTriCtrl = TextEditingController();
  bool _laChuHo = false;
  String _gioiTinh = 'Nam',
      _danToc = 'Kinh',
      _tonGiao = 'Không',
      _quocTich = 'Việt Nam';
  String? _khuPho;
  final _dsGioiTinh = ['Nam', 'Nữ'],
      _dsDanToc = ['Kinh', 'Khác'],
      _dsTonGiao = ['Không', 'Khác'],
      _dsQuocTich = ['Việt Nam', 'Khác'],
      _dsKhuPho = [
        'Bình Trung',
        'Giồng Cà',
        'Ninh Lộc',
        'Ninh Phú',
        'Ninh Thọ',
        'Ninh Trung',
        'Tân Hòa',
        'Tân Phước',
        'Thạnh Đông',
        'Thạnh Hiệp'
      ];

  @override
  void initState() {
    super.initState();
    if (widget.duLieuCu != null) {
      _hoTenCtrl.text = widget.duLieuCu!['ho_ten'] ?? '';
      _ngaySinhCtrl.text = widget.duLieuCu!['ngay_sinh'] ?? '';
      _cccdCtrl.text = widget.duLieuCu!['cccd'] ?? '';
      _sdtCtrl.text = widget.duLieuCu!['sdt'] ?? '';
      _ngheNghiepCtrl.text = widget.duLieuCu!['nghe_nghiep'] ?? '';
      _soNhaCtrl.text = widget.duLieuCu!['so_nha'] ?? '';
      _toDCTQCtrl.text = widget.duLieuCu!['to_dctq'] ?? '';
      _viTriCtrl.text = widget.duLieuCu!['vi_tri'] ?? '';
      _laChuHo = widget.duLieuCu!['la_chu_ho'] ?? false;
      if (_dsKhuPho.contains(widget.duLieuCu!['khu_pho']))
        _khuPho = widget.duLieuCu!['khu_pho'];
    }
  }

  @override
  Widget build(BuildContext context) {
    bool laCheDoSua = widget.documentId != null;
    return AlertDialog(
      title: Text(laCheDoSua ? 'Cập nhật' : 'Thêm nhân khẩu',
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                  title: const Text('Người này là CHỦ HỘ',
                      style: TextStyle(color: Colors.green, fontSize: 13)),
                  value: _laChuHo,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => _laChuHo = v ?? false)),
              TextField(
                  controller: _hoTenCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên')),
              TextField(
                  controller: _ngaySinhCtrl,
                  decoration: const InputDecoration(labelText: 'Ngày sinh')),
              DropdownButtonFormField<String>(
                  value: _gioiTinh,
                  items: _dsGioiTinh
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _gioiTinh = v!)),
              TextField(
                  controller: _cccdCtrl,
                  decoration: const InputDecoration(labelText: 'CCCD')),
              TextField(
                  controller: _sdtCtrl,
                  decoration: const InputDecoration(labelText: 'SĐT')),
              TextField(
                  controller: _soNhaCtrl,
                  decoration: const InputDecoration(labelText: 'Số nhà')),
              DropdownButtonFormField<String>(
                  value: _khuPho,
                  hint: const Text('Khu phố'),
                  items: _dsKhuPho
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _khuPho = v)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () {
            Map<String, dynamic> dl = {
              'la_chu_ho': _laChuHo,
              'ho_ten': _hoTenCtrl.text,
              'ngay_sinh': _ngaySinhCtrl.text,
              'gioi_tinh': _gioiTinh,
              'dan_toc': _danToc,
              'ton_giao': _tonGiao,
              'quoc_tich': _quocTich,
              'cccd': _cccdCtrl.text,
              'sdt': _sdtCtrl.text,
              'nghe_nghiep': _ngheNghiepCtrl.text,
              'so_nha': _soNhaCtrl.text,
              'to_dctq': _toDCTQCtrl.text,
              'khu_pho': _khuPho ?? '',
              'vi_tri': _viTriCtrl.text
            };
            laCheDoSua
                ? FirebaseFirestore.instance
                    .collection('nhan_khau')
                    .doc(widget.documentId)
                    .update(dl)
                : FirebaseFirestore.instance.collection('nhan_khau').add(dl);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: Text(laCheDoSua ? 'Cập nhật' : 'Lưu'),
        ),
      ],
    );
  }
}
