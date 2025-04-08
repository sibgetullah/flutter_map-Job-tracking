import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:esay/maps/map_service.dart';

class UsersInAreaPage extends StatefulWidget {
  final int jobId;

  UsersInAreaPage({required this.jobId});

  @override
  _UsersInAreaPageState createState() => _UsersInAreaPageState();
}

class _UsersInAreaPageState extends State<UsersInAreaPage> {
  List<LatLng> _polygonPoints = [];
  List<Map<String, dynamic>> _usersInArea = [];
  LatLng? _currentUserLocation; // Giriş yapan kullanıcının konumu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // İşin alanını getir
      final polygonPoints = await MapsService.getJobArea(widget.jobId);
      // Alandaki kullanıcıları getir
      final usersInArea = await MapsService.getUsersInJobAreaWithLocations(widget.jobId);
      // Giriş yapan kullanıcının konumunu getir (varsayımsal metod)
      final currentUserLocation = await MapsService.getCurrentUserLocation();

      setState(() {
        _polygonPoints = polygonPoints;
        _usersInArea = usersInArea;
        _currentUserLocation = currentUserLocation;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yüklenirken hata oluştu: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alandaki Kullanıcılar'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Harita
                Expanded(
                  flex: 2,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _currentUserLocation ?? // Kullanıcının konumu varsa onu kullan
                          (_polygonPoints.isNotEmpty
                              ? _polygonPoints.first
                              : LatLng(41.0082397, 28.9783592)), // Varsayılan merkez
                      initialZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const [],
                      ),
                      if (_polygonPoints.isNotEmpty)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _polygonPoints,
                              color: Colors.blue.withOpacity(0.3),
                              borderStrokeWidth: 2.0,
                              borderColor: Colors.blue,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Giriş yapan kullanıcının konumu
                          if (_currentUserLocation != null)
                            Marker(
                              point: _currentUserLocation!,
                              width: 40.0,
                              height: 40.0,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bu sizin konumunuz')),
                                  );
                                },
                                child: Icon(
                                  Icons.my_location,
                                  color: Colors.green,
                                  size: 40,
                                ),
                              ),
                            ),
                          // Alandaki diğer kullanıcılar
                          ..._usersInArea
                              .where((user) =>
                                  user['latitude'] != null && user['longitude'] != null)
                              .map((user) {
                            return Marker(
                              point: LatLng(user['latitude'], user['longitude']),
                              width: 40.0,
                              height: 40.0,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${user['full_name']} - ${user['group_name']}'),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                // Kullanıcı Listesi
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Toplam Kullanıcı Sayısı: ${_usersInArea.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _usersInArea.length,
                          itemBuilder: (context, index) {
                            final user = _usersInArea[index];
                            return ListTile(
                              leading: Icon(Icons.person, color: Colors.blue[900]),
                              title: Text(user['full_name']),
                              subtitle: Text('Grup: ${user['group_name']}'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}