import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:esay/maps/map_service.dart';

class MapPage extends StatefulWidget {
  final int jobId;
  final Function(List<LatLng>, bool) onAreaSelected;

  const MapPage({
    required this.jobId,
    required this.onAreaSelected,
    Key? key,
  }) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<LatLng> _polygonPoints = [];
  Map<int, Map<String, dynamic>> _jobAreas = {};
  bool _isDrawing = false;
  bool _isLoading = true;
  LatLng? _currentUserLocation;
  final TextEditingController _areaNameController = TextEditingController();
  bool _isScanMode = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _currentUserLocation = await MapsService.getCurrentUserLocation();
      _jobAreas = await MapsService.getJobAreasByJobId(widget.jobId);
    } catch (e) {
      print('Veriler yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yüklenirken hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _isScanMode = false;
      _polygonPoints.clear();
    });
  }

  void _startScanMode() {
    setState(() {
      _isDrawing = true;
      _isScanMode = true;
      _polygonPoints.clear();
    });
  }

  void _addPoint(LatLng point) {
    if (_isDrawing) {
      setState(() {
        _polygonPoints.add(point);
      });
    }
  }

  Future<void> _saveArea() async {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alan oluşturmak için en az 3 nokta seçmelisiniz')),
      );
      return;
    }

    String areaName = "";

    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController _nameController = TextEditingController();
        return AlertDialog(
          title: const Text('Alan İsmi Girin'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Alan adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                areaName = _nameController.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (areaName.isEmpty) {
      areaName = "Alan ${_jobAreas.length + 1}";
    }

    try {
      final areaId = _jobAreas.isEmpty ? 1 : _jobAreas.keys.last + 1;
      await MapsService.addJobArea(
        jobId: widget.jobId,
        areaId: areaId,
        areaName: areaName,
        polygonPoints: _polygonPoints,
        isScanned: _isScanMode,
      );

      setState(() {
        _jobAreas[areaId] = {
          'points': List<LatLng>.from(_polygonPoints),
          'name': areaName,
          'isScanned': _isScanMode,
        };
        _isDrawing = false;
        _isScanMode = false;
        _polygonPoints.clear();
      });

      widget.onAreaSelected(_polygonPoints, _isScanMode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$areaName başarıyla kaydedildi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alan kaydedilirken hata: $e')),
      );
    }
  }

  Future<void> _deleteArea() async {
    if (_jobAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinecek alan yok')),
      );
      return;
    }

    final selectedAreaId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silmek İstediğiniz Alanı Seçin'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _jobAreas.entries.map((entry) {
              return ListTile(
                title: Text(entry.value['name']),
                onTap: () => Navigator.pop(context, entry.key),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (selectedAreaId != null) {
      try {
        await MapsService.deleteJobArea(widget.jobId, selectedAreaId);
        setState(() {
          _jobAreas.remove(selectedAreaId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alan başarıyla silindi')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alan silinirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alan Belirle'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentUserLocation ?? const LatLng(41.0082, 28.9784),
                    initialZoom: 18.0,
                    onTap: (tapPosition, point) => _addPoint(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const [],
                    ),
                    if (_jobAreas.isNotEmpty)
                      PolygonLayer(
                        polygons: _jobAreas.values.map(
                          (area) {
                            bool isScanned = area['isScanned'] ?? false;
                            return Polygon(
                              points: area['points'],
                              color: isScanned ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                              borderStrokeWidth: 2.0,
                              borderColor: isScanned ? Colors.red : Colors.blue,
                              isFilled: true,
                            );
                          },
                        ).toList(),
                      ),
                    if (_isDrawing && _polygonPoints.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            color: Colors.red.withOpacity(0.3),
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.red,
                            isFilled: _isScanMode,
                          ),
                        ],
                      ),
                    if (_isDrawing && _polygonPoints.isNotEmpty)
                      MarkerLayer(
                        markers: _polygonPoints.map(
                          (point) => Marker(
                            point: point,
                            width: 20.0,
                            height: 20.0,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ).toList(),
                      ),
                    if (_jobAreas.isNotEmpty)
                      MarkerLayer(
                        markers: _jobAreas.entries.map((entry) {
                          LatLng edgePoint = entry.value['points'].first;
                          return Marker(
                            point: edgePoint,
                            width: 100,
                            height: 40,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.value['name'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_jobAreas.isNotEmpty)
                        ElevatedButton(
                          onPressed: _deleteArea,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Alanları Sil'),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: ElevatedButton(
                                onPressed: _isDrawing ? null : _startDrawing,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                                child: const Text('Çizimi Başlat'),
                              ),
                            ),
                          ),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: ElevatedButton(
                                onPressed: _isDrawing ? null : _startScanMode,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                child: const Text('Alan Tara'),
                              ),
                            ),
                          ),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: ElevatedButton(
                                onPressed: _isDrawing ? _saveArea : null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Alanı Kaydet'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    double latSum = 0;
    double lngSum = 0;
    for (var point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  @override
  void dispose() {
    _areaNameController.dispose();
    super.dispose();
  }
}