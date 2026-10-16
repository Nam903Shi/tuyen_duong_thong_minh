import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class TrangChu extends StatefulWidget {
  const TrangChu({super.key});
  @override
  State<TrangChu> createState() => _TrangChuState();
}

class _TrangChuState extends State<TrangChu> {
  final MapController _mapController = MapController();
  final TextEditingController _timKiemCtrl = TextEditingController();

  // Tâm bản đồ đặt chính giữa khu vực phường Bình Minh
  final LatLng _toaDoTrungTam = const LatLng(11.3850, 106.1350);
  LatLng? _viTriTimKiem;
  bool _laBanDoVeTinh = false;
  bool _dangTimKiem = false;

  Future<LatLng?> _timQuaArcGIS(String query) async {
    try {
      String encoded = Uri.encodeComponent(query);
      String url =
          "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates"
          "?SingleLine=$encoded"
          "&searchExtent=106.0480,11.3220,106.2050,11.4520"
          "&countryCode=VNM&maxLocations=1&f=json";
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không tìm thấy "$tuKhoa". Anh có thể chạm trực tiếp vào bản đồ để ghim vị trí!',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối mạng: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangTimKiem = false);
    }
  }

  Future<void> _dangXuat() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ManHinhDangNhapCanBo()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bản Đồ Quản Trị Phường Bình Minh',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _dangXuat,
            tooltip: 'Đăng xuất',
          ),
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
              // Chạm vào bất kỳ điểm nào trên bản đồ để cắm ghim đỏ vị trí cần quản lý
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
              // Chỉ hiển thị marker ghim đỏ khi người dùng thực hiện tìm kiếm hoặc chạm trực tiếp lên bản đồ
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
                ],
              ),
              child: TextField(
                controller: _timKiemCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _xuLyTimKiemDiaChi(),
                decoration: InputDecoration(
                  hintText: 'Tìm đường, địa điểm tại Bình Minh...',
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  suffixIcon: _dangTimKiem
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.green),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, color: Colors.green),
                          onPressed: _xuLyTimKiemDiaChi,
                        ),
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
              tooltip: 'Đổi lớp bản đồ Giao thông / Vệ tinh',
              onPressed: () => setState(() => _laBanDoVeTinh = !_laBanDoVeTinh),
              child: Icon(
                _laBanDoVeTinh ? Icons.map : Icons.satellite_alt,
                color: Colors.green,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'map_center',
              backgroundColor: Colors.white,
              tooltip: 'Về trung tâm Bình Minh',
              onPressed: () {
                _mapController.move(_toaDoTrungTam, 13.5);
                setState(() => _viTriTimKiem = null);
                _timKiemCtrl.clear();
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
