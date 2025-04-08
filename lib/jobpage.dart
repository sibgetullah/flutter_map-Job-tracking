import 'dart:io';
import 'package:esay/StoragePermissionService.dart';
import 'package:esay/add_user_options_page.dart';
import 'package:esay/login_page_afad.dart';
import 'package:esay/maps/map_page.dart';
import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:esay/maps/map_service.dart';
import 'package:esay/qr_code_entry_page.dart';
import 'package:esay/job_report_page.dart'; // Rapor sayfaları için import

class JobDetailsPage extends StatefulWidget {
  final String jobTitle;
  String description; // Mutable hale getirildi
  final String createdBy;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int jobId;

  JobDetailsPage({
    required this.jobTitle,
    required this.description,
    required this.createdBy,
    this.startTime,
    this.endTime,
    required this.isAdmin,
    this.onEdit,
    this.onDelete,
    required this.jobId, required isLocked, Null Function()? CompassPoint,
  });

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  List<String> groupNames = [];
  List<Map<String, dynamic>> users = [];
  Map<String, bool> userSelections = {};
  List<int> attendedUsers = [];
  Map<int, Map<String, dynamic>> jobAreas = {}; // İş alanlarını saklamak için güncellendi
  List<List<Map<String, dynamic>>> clusteredUsers = [];
  List<Map<String, dynamic>> taskEntries = [];
  List<Map<String, dynamic>> extraTaskEntries = [];
  List<Map<String, dynamic>> attendedUsersLog = [];
  late MapController _mapController;
  String? _creatorFullName;
  bool _isUpdating = false;

  final Color afadDarkBlue = const Color(0xFF0054A6);
  final Color afadWhite = Colors.white;
  final Color afadGrey = Colors.grey[700]!;
  final TextStyle titleStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0054A6));
  final TextStyle subtitleStyle = TextStyle(fontSize: 16, color: Colors.grey[700]!);
  final TextStyle buttonTextStyle = const TextStyle(fontSize: 14, color: Colors.white);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadGroupNames(),
      _loadUserNames(),
      _loadAttendedUsers(),
      _loadJobAreas(),
      _loadTaskEntries(),
      _loadExtraTaskEntries(),
      _loadCreatorFullName(),
      _loadAttendedUsersLog(),
      _loadDescription(),
    ]);
  }

  Future<void> _loadDescription() async {
    try {
      await DatabaseHelper.ensureConnection();
      final jobInfo = await DatabaseHelper.getJobById(widget.jobId);
      setState(() {
        widget.description = jobInfo?['description'] ?? 'Açıklama Yok';
      });
    } catch (e) {
      debugPrint('Açıklama yüklenirken hata: $e');
    }
  }

  Future<void> _loadCreatorFullName() async {
    try {
      await DatabaseHelper.ensureConnection();
      final creatorId = int.tryParse(widget.createdBy.split(' ').last) ?? 0;
      if (creatorId != 0) {
        final userInfo = await DatabaseHelper.getUserById(creatorId);
        setState(() {
          _creatorFullName = userInfo['full_name']?.toString() ?? 'Bilinmeyen Kullanıcı';
        });
      } else {
        setState(() {
          _creatorFullName = widget.createdBy;
        });
      }
    } catch (e) {
      debugPrint('Oluşturanın tam adı yüklenirken hata: $e');
      setState(() {
        _creatorFullName = 'Hata: Bilgi Alınamadı';
      });
    }
  }

  Future<void> _loadGroupNames() async {
    try {
      final groups = await DatabaseHelper.getGroupNamesFromAssignedGroups(widget.jobId);
      setState(() => groupNames = groups);
    } catch (e) {
      debugPrint('Grup isimleri yüklenirken hata: $e');
    }
  }

  Future<void> _loadUserNames() async {
    try {
      final userList = await DatabaseHelper.getUserNamesFromAssignedUsers(widget.jobId);
      setState(() {
        users = userList;
        userSelections = {for (var user in userList) user['user_id'].toString(): false};
      });
    } catch (e) {
      debugPrint('Kullanıcı isimleri yüklenirken hata: $e');
    }
  }

  Future<void> _loadAttendedUsers() async {
    try {
      final attended = await DatabaseHelper.getAttendedUsers(widget.jobId);
      setState(() {
        attendedUsers = attended;
        for (var userId in attended) {
          userSelections[userId.toString()] = true;
        }
      });

      for (var user in users) {
        final userId = user['user_id'];
        final isInJobArea = await DatabaseHelper.isUserInJobArea(userId, widget.jobId);
        if (isInJobArea) {
          setState(() {
            userSelections[userId.toString()] = true;
          });
          final locations = await MapsService.getUserLocations(userId);
          if (locations.isNotEmpty) {
            setState(() {
              user['latitude'] = locations.first['latitude'];
              user['longitude'] = locations.first['longitude'];
            });
          } else {
            user['latitude'] = null;
            user['longitude'] = null;
          }
        }
      }
      _clusterUsers();
    } catch (e) {
      debugPrint('Katılan kullanıcılar yüklenirken hata: $e');
    }
  }

  Future<void> _loadJobAreas() async {
    try {
      final areas = await MapsService.getJobAreasByJobId(widget.jobId);
      if (mounted) {
        setState(() {
          jobAreas = areas;
          if (jobAreas.isNotEmpty) {
            _fitBoundsToAreas();
            // Alan isimlerini kontrol etmek için log ekle
            jobAreas.forEach((areaId, areaData) {
              debugPrint('Alan ID: $areaId, İsim: ${areaData['name']}, Noktalar: ${areaData['points']}');
            });
          }
        });
      }
    } catch (e) {
      debugPrint('İş alanları yüklenirken hata: $e');
    }
  }

  Future<void> _loadTaskEntries() async {
    try {
      final result = await DatabaseHelper.getTaskEntries(widget.jobId);
      setState(() => taskEntries = result);
    } catch (e) {
      debugPrint('Task entries yüklenirken hata: $e');
    }
  }

  Future<void> _loadExtraTaskEntries() async {
    try {
      final result = await DatabaseHelper.getExtraTaskEntries(widget.jobId);
      setState(() => extraTaskEntries = result);
    } catch (e) {
      debugPrint('Extra task entries yüklenirken hata: $e');
    }
  }

  Future<void> _loadAttendedUsersLog() async {
    try {
      final log = await DatabaseHelper.getAttendedUsersLog(widget.jobId);
      setState(() => attendedUsersLog = log);
    } catch (e) {
      debugPrint('Attended users log yüklenirken hata: $e');
    }
  }

  void _fitBoundsToAreas() {
    if (jobAreas.isNotEmpty) {
      final allPoints = jobAreas.values.expand((area) => area['points'] as List<LatLng>).toList();
      if (allPoints.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(20)));
      }
    }
  }

  void _clusterUsers() {
    const distance = Distance();
    final remainingUsers = users
        .where((user) => userSelections[user['user_id'].toString()] == true)
        .where((user) => user['latitude'] != null && user['longitude'] != null)
        .toList();
    clusteredUsers = [];

    while (remainingUsers.isNotEmpty) {
      final currentUser = remainingUsers.first;
      final currentLatLng = LatLng(currentUser['latitude'], currentUser['longitude']);
      final cluster = [currentUser];

      remainingUsers.removeAt(0);

      for (int i = remainingUsers.length - 1; i >= 0; i--) {
        final otherUser = remainingUsers[i];
        final otherLatLng = LatLng(otherUser['latitude'], otherUser['longitude']);
        final metersApart = distance(currentLatLng, otherLatLng);

        if (metersApart <= 10) {
          cluster.add(otherUser);
          remainingUsers.removeAt(i);
        }
      }
      clusteredUsers.add(cluster);
    }
  }

  Future<void> _updateAttendedUsers() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final selectedUsers = userSelections.entries
          .where((entry) => entry.value)
          .map((entry) => int.parse(entry.key))
          .toList();

      for (var userId in selectedUsers) {
        if (!attendedUsers.contains(userId)) {
          final entryTime = DateTime.now().toIso8601String();
          await DatabaseHelper.recordAttendedUserTime(widget.jobId, userId, entryTime);
        }
      }

      await DatabaseHelper.updateAttendedUsers(widget.jobId, selectedUsers);
      setState(() => attendedUsers = selectedUsers);
      await _loadAttendedUsersLog();
      debugPrint('Katılım durumu ve giriş zamanları güncellendi');
    } catch (e) {
      debugPrint('Katılım durumu güncellenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Katılım durumu güncellenirken hata: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _navigateToFullMap() {
    final selectedUserCount = _calculateTotalParticipants();
    final usersWithLocationCount = users
        .where((user) => userSelections[user['user_id'].toString()] == true)
        .where((user) => user['latitude'] != null && user['longitude'] != null)
        .length;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullMapPage(
          jobAreas: jobAreas,
          clusteredUsers: clusteredUsers,
          selectedUserCount: selectedUserCount,
          usersWithLocationCount: usersWithLocationCount,
        ),
      ),
    );
  }

  void _navigateToMapPage() {
    Navigator.push<(List<LatLng>, bool)>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          jobId: widget.jobId,
          onAreaSelected: (area, isScanned) => Navigator.pop(context, (area, isScanned)),
        ),
      ),
    ).then((result) {
      if (result != null && result.$1.isNotEmpty) {
        _loadJobAreas(); // Yeni alan eklendiğinde haritayı güncelle
      }
    });
  }

  void _navigateToAddUserOptions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddUserOptionsPage(jobId: widget.jobId)),
    ).then((_) => _loadInitialData());
  }

  void _navigateToQrCodeEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrCodeEntryPage(jobId: widget.jobId)),
    ).then((result) {
      if (result == true) {
        _loadInitialData();
      }
    });
  }

  void _navigateToAttendedUsersLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendedUsersLogPage(
          attendedUsersLog: attendedUsersLog,
          users: users,
          jobTitle: widget.jobTitle,
          description: widget.description,
          createdBy: _creatorFullName ?? widget.createdBy,
          startTime: widget.startTime,
        ),
      ),
    );
  }

  void _navigateToAssignedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignedUsersPage(
          users: users,
          userSelections: userSelections,
          jobId: widget.jobId,
          isAdmin: widget.isAdmin,
          onUpdate: _updateAttendedUsers,
          onClusterUsers: _clusterUsers,
          jobTitle: widget.jobTitle,
          description: widget.description,
          createdBy: _creatorFullName ?? widget.createdBy,
          startTime: widget.startTime,
        ),
      ),
    ).then((_) => _loadInitialData());
  }

  void _navigateToAssignedExtraTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignedExtraTasksPage(
          taskEntries: taskEntries,
          extraTaskEntries: extraTaskEntries,
          jobTitle: widget.jobTitle,
          description: widget.description,
          createdBy: _creatorFullName ?? widget.createdBy,
          startTime: widget.startTime,
        ),
      ),
    );
  }

  void _navigateToExtraTasksLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExtraTasksLogPage(
          taskEntries: taskEntries,
          extraTaskEntries: extraTaskEntries,
          jobTitle: widget.jobTitle,
          description: widget.description,
          createdBy: _creatorFullName ?? widget.createdBy,
          startTime: widget.startTime,
        ),
      ),
    );
  }

  void _generateFullReport() {
    ReportPages.generateFullReport(
      context,
      jobTitle: widget.jobTitle,
      description: widget.description,
      createdBy: _creatorFullName ?? widget.createdBy,
      startTime: widget.startTime,
      jobId: widget.jobId,
      users: users,
      userSelections: userSelections,
      taskEntries: taskEntries,
      extraTaskEntries: extraTaskEntries,
      attendedUsersLog: attendedUsersLog,
    );
  }

  int _calculateTotalParticipants() {
    final selectedUsersCount = userSelections.values.where((value) => value).length;
    final taskEntriesCount = taskEntries.fold<int>(0, (sum, entry) => sum + (entry['count'] as int? ?? 0));
    final extraTaskEntriesCount = extraTaskEntries.length;
    return selectedUsersCount + taskEntriesCount + extraTaskEntriesCount;
  }

  Widget _buildInfoTile(String label, String? value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_getIconForLabel(label), color: afadDarkBlue),
        title: Text(label, style: titleStyle),
        subtitle: Text(value ?? 'Bilgi Yok', style: subtitleStyle),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Ad Soyad':
        return Icons.person;
      case 'Unvan':
        return Icons.work;
      case 'Rol':
        return Icons.security;
      case 'Kan Grubu':
        return Icons.favorite;
      case 'Email':
        return Icons.email;
      case 'Telefon':
        return Icons.phone;
      default:
        return Icons.info;
    }
  }

  void _showUserListDialog(BuildContext context, List<Map<String, dynamic>> cluster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grup Kullanıcıları (${cluster.length} kişi)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cluster.length,
            itemBuilder: (context, index) {
              final user = cluster[index];
              return ListTile(
                leading: Icon(Icons.person, color: afadDarkBlue),
                title: Text(user['full_name']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: afadDarkBlue)),
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
Widget build(BuildContext context) {
  final selectedUserCount = _calculateTotalParticipants();
  final usersWithLocationCount = users
      .where((user) => userSelections[user['user_id'].toString()] == true)
      .where((user) => user['latitude'] != null && user['longitude'] != null)
      .length;
  final screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('İş Ayrıntıları', style: const TextStyle(color: Colors.white)),
      backgroundColor: afadDarkBlue,
      actions: [
        if (widget.isAdmin) ...[
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: widget.onEdit,
            tooltip: 'İşi Düzenle',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: widget.onDelete,
            tooltip: 'İşi Sil',
          ),
        ],
      ],
    ),
      body: SingleChildScrollView(
padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTile('İş Adı', widget.jobTitle),
            _buildInfoTile('Açıklama', widget.description),
            _buildInfoTile('Oluşturan', _creatorFullName ?? 'Yükleniyor...'),
            if (widget.startTime != null)
              _buildInfoTile('Başlangıç Tarihi', DateFormat('dd/MM/yyyy HH:mm').format(widget.startTime!)),
            const SizedBox(height: 16),
            Text('Atanan Gruplar:', style: titleStyle),
            const SizedBox(height: 8),
            if (groupNames.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groupNames.map((name) => Text('Grup: $name', style: subtitleStyle)).toList(),
              )
            else
              Text('Atanan grup bulunmamaktadır.', style: subtitleStyle),
            const SizedBox(height: 16),
            if (widget.isAdmin) ...[
              ElevatedButton(
                onPressed: _navigateToAssignedUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: afadDarkBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Atanan Kullanıcılar', style: buttonTextStyle),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToAttendedUsersLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: afadDarkBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Kullanıcılar Giriş Zamanları', style: buttonTextStyle),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToAssignedExtraTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: afadDarkBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Atanan Dış Görevli Zamanlı', style: buttonTextStyle),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _generateFullReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: afadDarkBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Toplu Rapor', style: buttonTextStyle),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: _navigateToAddUserOptions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: afadDarkBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Kişi Ekle', style: buttonTextStyle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: _navigateToMapPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: afadDarkBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Alan Ekle/Düzenle', style: buttonTextStyle),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Alandaki Kullanıcıların Konumları:', style: titleStyle),
            const SizedBox(height: 8),
SizedBox(
  height: 300,
  child: FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: const LatLng(41.0082397, 28.9783592),
      initialZoom: 18.0,
      onMapReady: _fitBoundsToAreas,
    ),
    children: [
      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const []),
      if (jobAreas.isNotEmpty)
        PolygonLayer(
          polygons: jobAreas.values.map((areaData) {
            final isScanned = areaData['isScanned'] as bool? ?? false;
            return Polygon(
              points: areaData['points'] as List<LatLng>,
              color: isScanned ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
              borderStrokeWidth: 2.0,
              borderColor: isScanned ? Colors.red : Colors.blue,
            );
          }).toList(),
        ),
      if (jobAreas.isNotEmpty)
        MarkerLayer(
          markers: jobAreas.entries.map((entry) {
            final areaData = entry.value;
            final points = areaData['points'] as List<LatLng>;
            final areaName = areaData['name'] as String? ?? 'Alan ${entry.key}';
            return Marker(
              point: points.first, // Değişiklik burada
              width: 100,
              height: 40,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  areaName,
                  style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
      MarkerLayer(
        markers: clusteredUsers.map((cluster) {
          final avgLat = cluster.map((u) => u['latitude'] as double).reduce((a, b) => a + b) / cluster.length;
          final avgLon = cluster.map((u) => u['longitude'] as double).reduce((a, b) => a + b) / cluster.length;
          return Marker(
            point: LatLng(avgLat, avgLon),
            width: 80.0,
            height: 80.0,
            child: GestureDetector(
              onTap: () => _showUserListDialog(context, cluster),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.group, color: Colors.red, size: 40),
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cluster.length}',
                        style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ],
  ),
),
            const SizedBox(height: 16),
            Text('Toplam Katılan Kullanıcı Sayısı: $selectedUserCount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: afadDarkBlue)),
            const SizedBox(height: 8),
            Text('Haritada Gösterilen Kullanıcı Sayısı: $usersWithLocationCount', style: TextStyle(fontSize: 16, color: afadGrey)),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: screenWidth * 0.6,
                child: ElevatedButton(
                  onPressed: _navigateToFullMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: afadDarkBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Büyük Haritada Göster', style: buttonTextStyle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullMapPage extends StatelessWidget {
  final Map<int, Map<String, dynamic>> jobAreas; // Güncellenen tür
  final List<List<Map<String, dynamic>>> clusteredUsers;
  final int selectedUserCount;
  final int usersWithLocationCount;

  const FullMapPage({
    required this.jobAreas,
    required this.clusteredUsers,
    required this.selectedUserCount,
    required this.usersWithLocationCount,
    Key? key,
  }) : super(key: key);

  void _showUserListDialog(BuildContext context, List<Map<String, dynamic>> cluster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grup Kullanıcıları (${cluster.length} kişi)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cluster.length,
            itemBuilder: (context, index) {
              final user = cluster[index];
              return ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF0054A6)),
                title: Text(user['full_name']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Color(0xFF0054A6))),
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
  Widget build(BuildContext context) {
    final mapController = MapController();

    void fitBounds() {
      if (jobAreas.isNotEmpty) {
        final allPoints = jobAreas.values.expand((area) => area['points'] as List<LatLng>).toList();
        if (allPoints.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(allPoints);
          mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(20)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tam Ekran Harita', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0054A6),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: jobAreas.isNotEmpty ? (jobAreas.values.first['points'] as List<LatLng>).first : const LatLng(41.0082397, 28.9783592),
              initialZoom: 18.0,
              onMapReady: fitBounds,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const []),
              if (jobAreas.isNotEmpty)
                PolygonLayer(
                  polygons: jobAreas.values.map((areaData) {
                    final isScanned = areaData['isScanned'] as bool? ?? false;
                    return Polygon(
                      points: areaData['points'] as List<LatLng>,
                      color: isScanned ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                      borderStrokeWidth: 2.0,
                      borderColor: isScanned ? Colors.red : Colors.blue,
                    );
                  }).toList(),
                ),
if (jobAreas.isNotEmpty)
  MarkerLayer(
    markers: jobAreas.entries.map((entry) {
      final areaData = entry.value;
      final points = areaData['points'] as List<LatLng>;
      final areaName = areaData['name'] as String? ?? 'Alan ${entry.key}';
      // final center = _calculatePolygonCenter(points); // Bu satırı kaldır
      return Marker(
        point: points.first, // Merkez yerine ilk noktayı kullan
        width: 100,
        height: 40,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            areaName,
            style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }).toList(),
  ),
              MarkerLayer(
                markers: clusteredUsers.map((cluster) {
                  final avgLat = cluster.map((u) => u['latitude'] as double).reduce((a, b) => a + b) / cluster.length;
                  final avgLon = cluster.map((u) => u['longitude'] as double).reduce((a, b) => a + b) / cluster.length;
                  return Marker(
                    point: LatLng(avgLat, avgLon),
                    width: 80.0,
                    height: 80.0,
                    child: GestureDetector(
                      onTap: () => _showUserListDialog(context, cluster),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.group, color: Colors.red, size: 40),
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${cluster.length}',
                                style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
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
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Toplam Katılan Kullanıcı: $selectedUserCount',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0054A6))),
                  const SizedBox(height: 5),
                  Text('Haritada Gösterilen: $usersWithLocationCount', style: TextStyle(fontSize: 16, color: Colors.grey[700]!)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendedUsersLogPage extends StatelessWidget {
  final List<Map<String, dynamic>> attendedUsersLog;
  final List<Map<String, dynamic>> users;
  final String jobTitle;
  final String description;
  final String createdBy;
  final DateTime? startTime;

  const AttendedUsersLogPage({
    required this.attendedUsersLog,
    required this.users,
    required this.jobTitle,
    required this.description,
    required this.createdBy,
    required this.startTime,
    Key? key,
  }) : super(key: key);

  void _generateReport(BuildContext context) {
    ReportPages.generateAttendedUsersLogReport(
      context,
      jobTitle: jobTitle,
      description: description,
      createdBy: createdBy,
      startTime: startTime,
      attendedUsersLog: attendedUsersLog,
      users: users,
    );
  }

  @override
  Widget build(BuildContext context) {
    final afadDarkBlue = const Color(0xFF0054A6);
    final afadWhite = Colors.white;
    final subtitleStyle = TextStyle(fontSize: 16, color: Colors.grey[700]!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriş Zamanları', style: TextStyle(color: Colors.white)),
        backgroundColor: afadDarkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: attendedUsersLog.isNotEmpty
                  ? ListView.builder(
                      itemCount: attendedUsersLog.length,
                      itemBuilder: (context, index) {
                        final log = attendedUsersLog[index];
                        final user = users.firstWhere(
                          (u) => u['user_id'] == log['user_id'],
                          orElse: () => <String, dynamic>{'full_name': 'Bilinmeyen Kullanıcı'},
                        );
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Icon(Icons.access_time, color: afadDarkBlue),
                            title: Text('👤 ${user['full_name']}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue)),
                            subtitle: Text(
                              'Giriş: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(log['entry_time']))}',
                              style: subtitleStyle,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(child: Text('Giriş kaydı bulunmamaktadır.', style: subtitleStyle)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _generateReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: afadDarkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rapor Al', style: TextStyle(fontSize: 14, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class AssignedUsersPage extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Map<String, bool> userSelections;
  final int jobId;
  final bool isAdmin;
  final Future<void> Function() onUpdate;
  final VoidCallback onClusterUsers;
  final String jobTitle;
  final String description;
  final String createdBy;
  final DateTime? startTime;

  const AssignedUsersPage({
    required this.users,
    required this.userSelections,
    required this.jobId,
    required this.isAdmin,
    required this.onUpdate,
    required this.onClusterUsers,
    required this.jobTitle,
    required this.description,
    required this.createdBy,
    required this.startTime,
    Key? key,
  }) : super(key: key);

  @override
  _AssignedUsersPageState createState() => _AssignedUsersPageState();
}

class _AssignedUsersPageState extends State<AssignedUsersPage> {
  final Color afadDarkBlue = const Color(0xFF0054A6);
  final Color afadWhite = Colors.white;
  final TextStyle subtitleStyle = TextStyle(fontSize: 16, color: Colors.grey[700]!);
  final TextStyle buttonTextStyle = const TextStyle(fontSize: 14, color: Colors.white);
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
    _searchController.addListener(_filterUsers);
    _checkSelectAllStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = widget.users
          .where((user) => user['full_name'].toString().toLowerCase().contains(query))
          .toList();
    });
  }

  void _checkSelectAllStatus() {
    // Tüm kullanıcılar seçili mi kontrol et (sadece filtrelenmiş olanları değil)
    final allSelected = widget.users.every((user) => 
        widget.userSelections[user['user_id'].toString()] == true);
    setState(() {
      _selectAll = allSelected;
    });
  }
void _toggleSelectAll(bool? value) async {
    if (value == null) return;

    // Eğer "Tümünü Seç" işaretleniyorsa uyarı göster
    if (value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emin misiniz?'),
          content: const Text('Bütün kullanıcılar giriş yapmış sayılacak. Devam etmek istiyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hayır', style: TextStyle(color: Color(0xFF0054A6))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Evet', style: TextStyle(color: Color(0xFF0054A6))),
            ),
          ],
        ),
      );

      // Kullanıcı "Hayır" derse işlemi iptal et
      if (confirm != true) return;
    }

    setState(() {
      _selectAll = value;
      // Tüm kullanıcıları seç (sadece filtrelenmiş olanları değil)
      for (var user in widget.users) {
        widget.userSelections[user['user_id'].toString()] = value;
      }
    });

    widget.onClusterUsers();
    await widget.onUpdate();
  }

  void _navigateToQrCodeEntry() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => QrCodeEntryPage(jobId: widget.jobId))).then((result) {
      if (result == true) {
        widget.onUpdate();
        widget.onClusterUsers();
      }
    });
  }

  void _generateReport(BuildContext context) {
    ReportPages.generateAssignedUsersReport(
      context,
      jobTitle: widget.jobTitle,
      description: widget.description,
      createdBy: widget.createdBy,
      startTime: widget.startTime,
      jobId: widget.jobId,
      users: widget.users,
      userSelections: widget.userSelections,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atanan Kullanıcılar', style: TextStyle(color: Colors.white)),
        backgroundColor: afadDarkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isAdmin) ...[
              Center(
                child: SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: _navigateToQrCodeEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: afadDarkBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('QR Kod ile Giriş', style: buttonTextStyle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Kullanıcı Ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Select all checkbox
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectAll,
                      onChanged: _toggleSelectAll,
                    ),
                    Text('Tümünü Seç', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _filteredUsers.isNotEmpty
                  ? ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final userId = user['user_id'].toString();
                        final userName = user['full_name'];

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Checkbox(
                              value: widget.userSelections[userId] ?? false,
                              onChanged: widget.isAdmin
                                  ? (value) async {
                                      setState(() {
                                        widget.userSelections[userId] = value ?? false;
                                        _checkSelectAllStatus();
                                      });
                                      widget.onClusterUsers();
                                      await widget.onUpdate();
                                    }
                                  : null,
                            ),
                            title: Text('👤 $userName', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue)),
                          ),
                        );
                      },
                    )
                  : Center(child: Text('Kullanıcı bulunamadı.', style: subtitleStyle)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _generateReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: afadDarkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Rapor Al', style: buttonTextStyle),
            ),
          ],
        ),
      ),
    );
  }
}

class AssignedExtraTasksPage extends StatelessWidget {
  final List<Map<String, dynamic>> taskEntries;
  final List<Map<String, dynamic>> extraTaskEntries;
  final String jobTitle;
  final String description;
  final String createdBy;
  final DateTime? startTime;

  const AssignedExtraTasksPage({
    required this.taskEntries,
    required this.extraTaskEntries,
    required this.jobTitle,
    required this.description,
    required this.createdBy,
    required this.startTime,
    Key? key,
  }) : super(key: key);

  void _generateReport(BuildContext context) {
    ReportPages.generateAssignedExtraTasksReport(
      context,
      jobTitle: jobTitle,
      description: description,
      createdBy: createdBy,
      startTime: startTime,
      taskEntries: taskEntries,
      extraTaskEntries: extraTaskEntries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final afadDarkBlue = const Color(0xFF0054A6);
    final afadWhite = Colors.white;
    final subtitleStyle = TextStyle(fontSize: 16, color: Colors.grey[700]!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atanan Dış Görevliler', style: TextStyle(color: Colors.white)),
        backgroundColor: afadDarkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: taskEntries.isNotEmpty || extraTaskEntries.isNotEmpty
                  ? ListView.builder(
                      itemCount: taskEntries.length + extraTaskEntries.length,
                      itemBuilder: (context, index) {
                        if (index < taskEntries.length) {
                          final entry = taskEntries[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(Icons.group, color: afadDarkBlue),
                              title: Text(
                                '👥 ${entry['count']} kişi (${entry['type']})',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue),
                              ),
                              subtitle: Text(
                                'Oluşturulma: ${DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'] as DateTime)}',
                                style: subtitleStyle,
                              ),
                            ),
                          );
                        } else {
                          final extraEntry = extraTaskEntries[index - taskEntries.length];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(Icons.person, color: afadDarkBlue),
                              title: Text(
                                '👤 ${extraEntry['team_name']} (TC: ${extraEntry['tc_kimlik_no']})',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue),
                              ),
                              subtitle: Text(
                                'Oluşturulma: ${DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'] as DateTime)}',
                                style: subtitleStyle,
                              ),
                            ),
                          );
                        }
                      },
                    )
                  : Center(child: Text('Atanan dış görevli bulunmamaktadır.', style: subtitleStyle)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _generateReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: afadDarkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rapor Al', style: TextStyle(fontSize: 14, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class ExtraTasksLogPage extends StatelessWidget {
  final List<Map<String, dynamic>> taskEntries;
  final List<Map<String, dynamic>> extraTaskEntries;
  final String jobTitle;
  final String description;
  final String createdBy;
  final DateTime? startTime;

  const ExtraTasksLogPage({
    required this.taskEntries,
    required this.extraTaskEntries,
    required this.jobTitle,
    required this.description,
    required this.createdBy,
    required this.startTime,
    Key? key,
  }) : super(key: key);

  void _generateReport(BuildContext context) {
    ReportPages.generateExtraTasksLogReport(
      context,
      jobTitle: jobTitle,
      description: description,
      createdBy: createdBy,
      startTime: startTime,
      taskEntries: taskEntries,
      extraTaskEntries: extraTaskEntries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final afadDarkBlue = const Color(0xFF0054A6);
    final afadWhite = Colors.white;
    final subtitleStyle = TextStyle(fontSize: 16, color: Colors.grey[700]!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dış Görevliler Zamanları', style: TextStyle(color: Colors.white)),
        backgroundColor: afadDarkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: taskEntries.isNotEmpty || extraTaskEntries.isNotEmpty
                  ? ListView.builder(
                      itemCount: taskEntries.length + extraTaskEntries.length,
                      itemBuilder: (context, index) {
                        if (index < taskEntries.length) {
                          final entry = taskEntries[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(Icons.access_time, color: afadDarkBlue),
                              title: Text(
                                '👥 ${entry['count']} kişi (${entry['type']})',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue),
                              ),
                              subtitle: Text(
                                'Zaman: ${DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'] as DateTime)}',
                                style: subtitleStyle,
                              ),
                            ),
                          );
                        } else {
                          final extraEntry = extraTaskEntries[index - taskEntries.length];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: Icon(Icons.access_time, color: afadDarkBlue),
                              title: Text(
                                '👤 ${extraEntry['team_name']} (TC: ${extraEntry['tc_kimlik_no']})',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: afadDarkBlue),
                              ),
                              subtitle: Text(
                                'Zaman: ${DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'] as DateTime)}',
                                style: subtitleStyle,
                              ),
                            ),
                          );
                        }
                      },
                    )
                  : Center(child: Text('Dış görevli kaydı bulunmamaktadır.', style: subtitleStyle)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _generateReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: afadDarkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Rapor Al', style: TextStyle(fontSize: 14, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}