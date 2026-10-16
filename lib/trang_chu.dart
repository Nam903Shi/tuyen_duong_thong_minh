import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'main.dart';

class TrangChu extends StatefulWidget {
  const TrangChu({super.key});
  @override
  State<TrangChu> createState() => _TrangChuState();
}

class _TrangChuState extends State<TrangChu> {
  final MapController _mapController = MapController();
  final TextEditingController _timKiemCtrl = TextEditingController();

  final LatLng _toaDoTrungTam = const LatLng(11.3850, 106.1350);
  LatLng? _viTriTimKiem;
  bool _laBanDoVeTinh = false;
  bool _dangTimKiem = false;
  bool _dangLayViTri = false;

  final _formKey = GlobalKey<FormState>();
  String _loaiDoiTuong = 'Nhà dân';
  final TextEditingController _chiTietCtrl = TextEditingController();

  Future<void> _layViTriHienTai() async {
    setState(() => _dangLayViTri = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Vui lòng bật GPS!'),
              backgroundColor: Colors.orange));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng toaDoHienTai = LatLng(position.latitude, position.longitude);

      setState(() {
        _viTriTimKiem = toaDoHienTai;
      });
      _mapController.move(toaDoHienTai, 18.0);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _dangLayViTri = false);
    }
  }

  void _hienThiFormNhapLieu() {
    if (_viTriTimKiem == null) return;
    _chiTietCtrl.clear();
    _loaiDoiTuong = 'Nhà dân';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cập nhật dữ liệu Hạ tầng',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _loaiDoiTuong,
                  decoration: const InputDecoration(
                      labelText: 'Loại đối tượng',
                      border: OutlineInputBorder()),
                  items: [
                    'Nhà dân',
                    'Trụ đèn chiếu sáng',
                    'Cây xanh đô thị',
                    'Khác'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                        value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _loaiDoiTuong = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _chiTietCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Thông tin chi tiết',
                    hintText: 'VD: Số nhà 123, Đường A / Trụ đèn số 5...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Vui lòng nhập thông tin' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Lưu lên hệ thống',
                        style: TextStyle(fontSize: 16)),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('ha_tang')
                              .add({
                            'loai': _loaiDoiTuong,
                            'chi_tiet': _chiTietCtrl.text.trim(),
                            'toa_do': GeoPoint(_viTriTimKiem!.latitude,
                                _viTriTimKiem!.longitude),
                            'ngay_tao': FieldValue.serverTimestamp(),
                            'nguoi_tao':
                                FirebaseAuth.instance.currentUser?.email ??
                                    'Cán bộ chưa rõ',
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Lưu thành công!'),
                                    backgroundColor: Colors.green));
                            setState(() => _viTriTimKiem = null);
                          }
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Lỗi: $e'),
                                backgroundColor: Colors.red));
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<LatLng?> _timQuaArcGIS(String query) async {
    try {
      String encoded = Uri.encodeComponent(query);
      String url =
          "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates?SingleLine=$encoded&searchExtent=106.0480,11.3220,106.2050,11.4520&countryCode=VNM&maxLocations=1&f=json";
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        var data = json.decode(res.body);
        if (data['candidates'] != null &&
            (data['candidates'] as List).isNotEmpty) {
          var loc = data['candidates'][0]['location'];
          return LatLng(
              (loc['y'] as num).toDouble(), (loc['x'] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<LatLng?> _timQuaPhoton(String query) async {
    try {
      String encoded = Uri.encodeComponent(query);
      String url =
          "https://photon.komoot.io/api/?q=$encoded&lat=11.3850&lon=106.1350&limit=1";
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        var data = json.decode(res.body);
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          List coords = data['features'][0]['geometry']['coordinates'];
          return LatLng(
              (coords[1] as num).toDouble(), (coords[0] as num).toDouble());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _xuLyTimKiemDiaChi() async {
    String tuKhoa = _timKiemCtrl.text.trim();
    if (tuKhoa.isEmpty) return;
    setState(() => _dangTimKiem = true);
    FocusScope.of(context).unfocus();
    try {
      LatLng? ketQua =
          await _timQuaArcGIS('$tuKhoa, Bình Minh, Tây Ninh, Việt Nam');
      ketQua ??= await _timQuaArcGIS('$tuKhoa, Tây Ninh, Việt Nam');
      ketQua ??= await _timQuaPhoton('$tuKhoa, Tây Ninh');
      if (ketQua != null) {
        setState(() {
          _viTriTimKiem = ketQua;
        });
        _mapController.move(_viTriTimKiem!, 16.5);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Không tìm thấy. Hãy chạm vào bản đồ!'),
              backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _dangTimKiem = false);
    }
  }

  Future<void> _dangXuat() async {
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const ManHinhDangNhapCanBo()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ Quản Trị',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _dangXuat)
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _toaDoTrungTam,
              initialZoom: 13.5,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (tapPosition, point) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _viTriTimKiem = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _laBanDoVeTinh
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              ),
              if (_viTriTimKiem != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _viTriTimKiem!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 45),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3))
                  ]),
              child: TextField(
                controller: _timKiemCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _xuLyTimKiemDiaChi(),
                decoration: InputDecoration(
                  hintText: 'Tìm đường, địa điểm...',
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  suffixIcon: _dangTimKiem
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.green))
                      : IconButton(
                          icon: const Icon(Icons.search, color: Colors.green),
                          onPressed: _xuLyTimKiemDiaChi),
                ),
              ),
            ),
          ),
          Positioned(
            top: 85,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'map_layer',
              backgroundColor: Colors.white,
              mini: true,
              onPressed: () => setState(() => _laBanDoVeTinh = !_laBanDoVeTinh),
              child: Icon(_laBanDoVeTinh ? Icons.map : Icons.satellite_alt,
                  color: Colors.green),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'map_center',
              backgroundColor: Colors.white,
              onPressed: _dangLayViTri ? null : _layViTriHienTai,
              child: _dangLayViTri
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.blue))
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          if (_viTriTimKiem != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 80,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.add_location_alt, size: 24),
                label: const Text('Lưu thông tin tại đây',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _hienThiFormNhapLieu,
              ),
            ),
        ],
      ),
    );
  }
}
