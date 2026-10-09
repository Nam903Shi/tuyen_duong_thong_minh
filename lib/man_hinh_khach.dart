import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ManHinhKhach extends StatefulWidget {
  const ManHinhKhach({super.key});

  @override
  State<ManHinhKhach> createState() => _ManHinhKhachState();
}

class _ManHinhKhachState extends State<ManHinhKhach> {
  final MapController _mapController = MapController();
  final TextEditingController _timKiemSoNhaCtrl = TextEditingController();

  final LatLng _toaDoDuongBoiLoi = const LatLng(11.3650, 106.1280);
  LatLng? _toaDoTimKiem;
  String? _tenDiaDiemTimKiem;
  bool _hienThiThongTin = true;
  bool _laBanDoVeTinh = true; // Bật mặc định chế độ vệ tinh GIS của Google

  final Map<String, dynamic> _thongTinTuyenDuong = {
    'ten_duong': 'Đường Bời Lời',
    'chieu_dai': '3.500 m',
    'chieu_rong': '12 m',
    'lo_gioi': '30 m',
    'doan_duong': 'Từ ngã tư Bình Minh đến chân núi Bà Đen',
  };

  // Hàm loại bỏ dấu tiếng Việt để tìm kiếm thông minh hơn
  String boDauTiengViet(String str) {
    str = str.toLowerCase();
    str = str.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    return str;
  }

  // Cơ sở dữ liệu tọa độ thực tế (Demo)
  final Map<String, LatLng> _duLieuDiaDiem = {
    '10': const LatLng(11.3610, 106.1265),
    '40': const LatLng(11.3645, 106.1278),
    'bo to moc tien': const LatLng(11.3662, 106.1285),
    'cho ninh son':
        const LatLng(11.3392, 106.1362), // Tọa độ thực của Chợ Ninh Sơn
    'ubnd phuong binh minh': const LatLng(11.3650, 106.1280),
    'cafe': const LatLng(11.3652, 106.1270),
  };

  void _xuLyTimKiem(String tuKhoa) {
    FocusScope.of(context).unfocus(); // Hạ bàn phím
    if (tuKhoa.trim().isEmpty) return;

    String queryKhongDau = boDauTiengViet(tuKhoa.trim());
    LatLng? ketQuaToaDo;
    String tenHienThi = '';

    // Quét tìm trong cơ sở dữ liệu
    _duLieuDiaDiem.forEach((key, latLng) {
      if (queryKhongDau.contains(key) || key.contains(queryKhongDau)) {
        ketQuaToaDo = latLng;
        tenHienThi = key.numericOnly() ? 'Số nhà $key Bời Lời' : tuKhoa;
      }
    });

    // Xử lý nếu KHÔNG TÌM THẤY trong hệ thống
    if (ketQuaToaDo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Không tìm thấy "$tuKhoa" trong cơ sở dữ liệu của Phường!'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Dừng lại, không cho nhảy bản đồ lung tung
    }

    // Nếu tìm thấy thì mới dịch chuyển bản đồ
    setState(() {
      _toaDoTimKiem = ketQuaToaDo;
      _tenDiaDiemTimKiem = tenHienThi;
      _hienThiThongTin = false;
    });

    // Phóng to bản đồ vệ tinh lên mức 18 để thấy rõ mái nhà
    _mapController.move(ketQuaToaDo!, 18.0);
  }

  Future<void> _moGoogleMapsDanDuong(LatLng destination) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _hienFormPhanAnh() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FormPhanAnhNhanh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> danhSachGhim = [
      Marker(
        point: _toaDoDuongBoiLoi,
        width: 50,
        height: 50,
        child: const Tooltip(
            message: 'Đường Bời Lời',
            child: Icon(Icons.location_on, color: Colors.blue, size: 40)),
      ),
    ];

    if (_toaDoTimKiem != null) {
      danhSachGhim.add(
        Marker(
          point: _toaDoTimKiem!,
          width: 60,
          height: 60,
          child: const Tooltip(
            message: 'Vị trí cần tìm',
            child: Icon(Icons.pin_drop, color: Colors.redAccent, size: 48),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // BẢN ĐỒ GOOGLE GIS / HYBRID HOẶC STREET
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _toaDoDuongBoiLoi,
              initialZoom: 16.0,
              onTap: (_, __) => setState(() => _hienThiThongTin = false),
            ),
            children: [
              TileLayer(
                // Đổi link Google Maps theo loại bản đồ (lyrs=y là Vệ tinh lai GIS, lyrs=m là Đường phố thường)
                urlTemplate: _laBanDoVeTinh
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              ),
              MarkerLayer(markers: danhSachGhim),
            ],
          ),

          // THANH TÌM KIẾM ĐƯỢC LÀM LẠI HOÀN TOÀN
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  // Nút Quay lại
                  Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Ô Tìm kiếm (Mở rộng toàn phần)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: TextField(
                        controller: _timKiemSoNhaCtrl,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Nhập số nhà, tên quán cần tìm...',
                          hintStyle: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          // Nút Kính lúp dính chặt vào trong TextField
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Material(
                              color: Colors.green,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.search,
                                    color: Colors.white, size: 22),
                                onPressed: () =>
                                    _xuLyTimKiem(_timKiemSoNhaCtrl.text),
                              ),
                            ),
                          ),
                        ),
                        onSubmitted: (value) => _xuLyTimKiem(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Nút QR Code
                  Material(
                    color: Colors.orange,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner,
                          color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Đã quét QR tuyến đường Bời Lời!')),
                        );
                        setState(() => _hienThiThongTin = true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // NÚT CHUYỂN ĐỔI BẢN ĐỒ VỆ TINH GIS / BẢN ĐỒ ĐƯỜNG
          Positioned(
            top: 84,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'chuyen_map_khach',
                backgroundColor: Colors.white,
                child: Icon(_laBanDoVeTinh ? Icons.map : Icons.satellite_alt,
                    color: Colors.blue),
                onPressed: () {
                  setState(() {
                    _laBanDoVeTinh = !_laBanDoVeTinh;
                  });
                },
              ),
            ),
          ),

          // BẢNG KẾT QUẢ TÌM KIẾM
          if (_toaDoTimKiem != null)
            Positioned(
              top: 84,
              left: 16,
              right: 64, // Chừa không gian cho nút đổi bản đồ
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.red, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tenDiaDiemTimKiem ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const Text('Bấm để mở Google Maps dẫn đường',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                        onPressed: () => _moGoogleMapsDanDuong(_toaDoTimKiem!),
                        child: const Text('Dẫn đường'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _toaDoTimKiem = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // THÔNG TIN TUYẾN ĐƯỜNG (BÊN DƯỚI)
          if (_hienThiThongTin)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_thongTinTuyenDuong['ten_duong'],
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () =>
                              setState(() => _hienThiThongTin = false),
                        )
                      ],
                    ),
                    Text(_thongTinTuyenDuong['doan_duong'],
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _chiSoTuyenDuong(Icons.straighten, 'Chiều dài',
                            _thongTinTuyenDuong['chieu_dai']),
                        _chiSoTuyenDuong(Icons.width_normal, 'Chiều rộng',
                            _thongTinTuyenDuong['chieu_rong']),
                        _chiSoTuyenDuong(Icons.architecture, 'Lộ giới xây dựng',
                            _thongTinTuyenDuong['lo_gioi']),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _hienFormPhanAnh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_alert, size: 24),
                        label: const Text('PHẢN ÁNH HIỆN TRƯỜNG',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5)),
                      ),
                    )
                  ],
                ),
              ),
            ),

          if (!_hienThiThongTin && _toaDoTimKiem == null)
            Positioned(
              bottom: 24,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: _hienFormPhanAnh,
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_alert),
                label: const Text('Phản ánh sự cố',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chiSoTuyenDuong(IconData icon, String tieuDe, String giaTri) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 24),
        const SizedBox(height: 4),
        Text(tieuDe, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(giaTri,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

extension StringExtension on String {
  bool numericOnly() {
    return double.tryParse(this) != null;
  }
}

// FORM PHẢN ÁNH NHANH CHO DÂN
class FormPhanAnhNhanh extends StatefulWidget {
  const FormPhanAnhNhanh({super.key});

  @override
  State<FormPhanAnhNhanh> createState() => _FormPhanAnhNhanhState();
}

class _FormPhanAnhNhanhState extends State<FormPhanAnhNhanh> {
  final _noiDungCtrl = TextEditingController();
  final _sdtDienThoaiCtrl = TextEditingController();
  final _linkAnhCtrl = TextEditingController();
  bool _dangGui = false;

  Future<void> _guiPhanAnh() async {
    if (_noiDungCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập nội dung sự cố!')));
      return;
    }
    setState(() => _dangGui = true);

    try {
      DateTime now = DateTime.now();
      String ngayFormat =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

      await FirebaseFirestore.instance.collection('phan_anh').add({
        'noi_dung': _noiDungCtrl.text,
        'vi_tri': 'Tuyến đường Bời Lời',
        'toa_do': '11.365510, 106.128850',
        'phan_loai': 'Khác',
        'muc_do': 'Trung bình',
        'nguoi_bao': _sdtDienThoaiCtrl.text.isEmpty
            ? 'Người dân'
            : _sdtDienThoaiCtrl.text,
        'trang_thai': 'Chưa xử lý',
        'ngay_bao': ngayFormat,
        'anh_ket_qua': _linkAnhCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text('Gửi Thành Công!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 8),
                const Text(
                    'UBND Phường đã tiếp nhận phản ánh của bạn. Xin cảm ơn!',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: const Text('Đóng'),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            const Text('Gửi Phản Ánh Hiện Trường',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
            const SizedBox(height: 4),
            const Text(
                'Hệ thống sẽ tự động ghi nhận tọa độ GPS hiện tại của bạn.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: _noiDungCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'VD: Có hố ga hỏng nắp, tụ tập kẹt xe...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sdtDienThoaiCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Số điện thoại liên hệ (Không bắt buộc)',
                prefixIcon: const Icon(Icons.phone, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkAnhCtrl,
              decoration: InputDecoration(
                hintText: 'Nhập đường dẫn ảnh hiện trường (Tùy chọn)',
                prefixIcon: const Icon(Icons.link, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _dangGui ? null : _guiPhanAnh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _dangGui
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Text('GỬI PHẢN ÁNH NGAY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
