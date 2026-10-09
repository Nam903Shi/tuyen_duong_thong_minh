import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class TrangCongDan extends StatefulWidget {
  const TrangCongDan({super.key});
  @override
  State<TrangCongDan> createState() => _TrangCongDanState();
}

class _TrangCongDanState extends State<TrangCongDan> {
  final MapController _mapController = MapController();
  final LatLng _toaDoUBNDBinhMinh = const LatLng(11.3650, 106.1280);
  LatLng? _viTriHienTaiCuaToi;
  bool _laBanDoVeTinh = false;

  final List<LatLng> _ranhGioiBinhMinh = [
    const LatLng(11.3850, 106.1150),
    const LatLng(11.3900, 106.1300),
    const LatLng(11.3820, 106.1550),
    const LatLng(11.3500, 106.1520),
    const LatLng(11.3320, 106.1400),
    const LatLng(11.3480, 106.1100),
  ];

  final Map<String, Map<String, String>> _duLieuTuyenDuong = {
    'duong_boi_loi': {
      'ten': 'Đường Bời Lời',
      'mo_ta': 'Từ ngã tư Bình Minh đến chân núi Bà Đen',
      'chieu_dai': '3.500 m',
      'chieu_rong': '12 m',
      'lo_gioi': '30 m'
    },
  };

  @override
  void initState() {
    super.initState();
    _yeuCauQuyenVaLayViTri();
  }

  Future<void> _yeuCauQuyenVaLayViTri() async {
    Map<Permission, PermissionStatus> statuses =
        await [Permission.camera, Permission.location].request();
    if (statuses[Permission.location]!.isGranted) {
      _layViTriRealTime();
    }
  }

  Future<void> _layViTriRealTime() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
    if (mounted) {
      setState(() {
        _viTriHienTaiCuaToi = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_viTriHienTaiCuaToi!, 15.5);
    }
  }

  Future<void> _quetQRTuyenDuong() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Phải cấp quyền Camera để quét mã QR!'),
              backgroundColor: Colors.red));
        return;
      }
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Đưa mã QR trên biển báo vào khung hình',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String code = barcodes.first.rawValue ?? '';
                    Navigator.pop(context);
                    _hienThiThongTinDuong(code);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hienThiThongTinDuong(String maQR) {
    String maXuLy = maQR.trim().toLowerCase();
    if (_duLieuTuyenDuong.containsKey(maXuLy)) {
      var t = _duLieuTuyenDuong[maXuLy]!;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t['ten']!,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              Text(t['mo_ta']!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _taoCotThongTin(
                      Icons.straighten, 'Chiều dài', t['chieu_dai']!),
                  _taoCotThongTin(Icons.width_normal, 'Rộng', t['chieu_rong']!),
                  _taoCotThongTin(Icons.architecture, 'Lộ giới', t['lo_gioi']!),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white),
                      child: const Text('Đã hiểu')))
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mã QR không thuộc tuyến đường quản lý!'),
          backgroundColor: Colors.red));
    }
  }

  Widget _taoCotThongTin(IconData icon, String tieuDe, String giaTri) {
    return Column(children: [
      Icon(icon, color: Colors.grey, size: 28),
      Text(tieuDe, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Text(giaTri,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
    ]);
  }

  Future<void> _phanAnhHienTruongVoiGPSVaCamera() async {
    if (_viTriHienTaiCuaToi == null) await _yeuCauQuyenVaLayViTri();
    if (_viTriHienTaiCuaToi == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không thể lấy được GPS. Vui lòng bật định vị!')));
      return;
    }

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? photo =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    String anhBase64 = '';
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      anhBase64 = base64Encode(bytes);
    }

    if (mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => FormNhanHuu(
              toaDoGPS:
                  '${_viTriHienTaiCuaToi!.latitude.toStringAsFixed(6)}, ${_viTriHienTaiCuaToi!.longitude.toStringAsFixed(6)}',
              anhHienTruong: anhBase64));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
                initialCenter: _toaDoUBNDBinhMinh, initialZoom: 14.5),
            children: [
              TileLayer(
                  urlTemplate: _laBanDoVeTinh
                      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
              PolygonLayer<Object>(
                polygons: [
                  Polygon(
                      points: _ranhGioiBinhMinh,
                      color: Colors.green.withOpacity(0.15),
                      borderStrokeWidth: 3,
                      borderColor: Colors.greenAccent),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                      point: _toaDoUBNDBinhMinh,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.account_balance,
                          color: Colors.orange, size: 30)),
                  if (_viTriHienTaiCuaToi != null)
                    Marker(
                      point: _viTriHienTaiCuaToi!,
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  shape: BoxShape.circle)),
                          Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // THANH TÌM KIẾM Ở TRÊN CÙNG
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ]),
                  child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ]),
                    child: const TextField(
                      decoration: InputDecoration(
                          hintText: 'Nhập tên địa điểm...',
                          prefixIcon: Icon(Icons.search, color: Colors.green),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // NÚT CHUYỂN ĐỔI BẢN ĐỒ VỆ TINH
          Positioned(
            top: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'btn_doi_map',
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              onPressed: () => setState(() => _laBanDoVeTinh = !_laBanDoVeTinh),
              child: Icon(_laBanDoVeTinh ? Icons.map : Icons.satellite_alt),
            ),
          ),

          Positioned(
            bottom: 150,
            right: 16,
            child: FloatingActionButton(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                onPressed: _layViTriRealTime,
                child: const Icon(Icons.my_location)),
          ),

          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _phanAnhHienTruongVoiGPSVaCamera,
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('PHẢN ÁNH BẰNG HÌNH ẢNH',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 6),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _quetQRTuyenDuong,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('QUÉT MÃ QR BIỂN ĐƯỜNG',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 6),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class FormNhanHuu extends StatefulWidget {
  final String toaDoGPS;
  final String anhHienTruong;
  const FormNhanHuu(
      {super.key, required this.toaDoGPS, required this.anhHienTruong});
  @override
  State<FormNhanHuu> createState() => _FormNhanHuuState();
}

class _FormNhanHuuState extends State<FormNhanHuu> {
  final _noiDungCtrl = TextEditingController();
  final _nguoiBaoCtrl = TextEditingController();
  String _phanLoai = 'Giao thông';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gửi phản ánh sự cố',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.anhHienTruong.isNotEmpty)
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(widget.anhHienTruong),
                      height: 150, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.gps_fixed, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text('Tọa độ: ${widget.toaDoGPS}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue))
                ])),
            const SizedBox(height: 12),
            TextField(
                controller: _noiDungCtrl,
                decoration: const InputDecoration(
                    labelText: 'Mô tả sự cố (VD: Kẹt xe)',
                    border: OutlineInputBorder()),
                maxLines: 2),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                value: _phanLoai,
                decoration: const InputDecoration(
                    labelText: 'Phân loại', border: OutlineInputBorder()),
                items: ['Giao thông', 'Môi trường', 'An ninh', 'Khác']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _phanLoai = v!)),
            const SizedBox(height: 12),
            TextField(
                controller: _nguoiBaoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Họ tên / SĐT (Tùy chọn)',
                    border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('phan_anh').add({
              'noi_dung': _noiDungCtrl.text,
              'toa_do': widget.toaDoGPS,
              'vi_tri': 'Gửi từ định vị tự động',
              'phan_loai': _phanLoai,
              'muc_do': 'Trung bình',
              'nguoi_bao': _nguoiBaoCtrl.text.isEmpty
                  ? 'Người dân (Ẩn danh)'
                  : _nguoiBaoCtrl.text,
              'trang_thai': 'Chưa xử lý',
              'ngay_bao':
                  "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
              'anh_ket_qua': widget.anhHienTruong
            });
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Đã gửi thành công!'),
                  backgroundColor: Colors.green));
            }
          },
          child: const Text('GỬI NGAY'),
        ),
      ],
    );
  }
}
