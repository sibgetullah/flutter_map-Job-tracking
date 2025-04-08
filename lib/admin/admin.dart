import 'dart:async';
import 'package:esay/flutter_foreground_task.dart';
import 'package:esay/maps/map_page.dart';
import 'package:esay/maps/users_in_area_page.dart';
import 'package:esay/user_infopage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'job_management_widgets.dart';
import 'job_management_service.dart';
import 'job_management_utils.dart';
import '../jobpage.dart';
import '../login_page_afad.dart';
import 'package:esay/connect_afad.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:esay/maps/map_service.dart';
import 'package:latlong2/latlong.dart';
import 'job_lock_widget.dart';

class JobManagementPage extends StatefulWidget {
  final int userId;
  final bool isAdmin;

  const JobManagementPage({required this.userId, required this.isAdmin});

  @override
  _JobManagementPageState createState() => _JobManagementPageState();
}

class _JobManagementPageState extends State<JobManagementPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _jobs = [];
  TextEditingController jobController = TextEditingController();
  AnimationController? _animationController;
  Animation<Color?>? _colorAnimation;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  Map<String, dynamic> _userInfo = {};
  bool _isUserInfoPanelOpen = false;
  bool _isLoadingUserInfo = false;
  LatLng? _currentUserLocation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadJobsWithLockStatus();
    _loadUserInfo();
    _loadCurrentUserLocation();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController!.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController!.forward();
        }
      });
  }

  Future<void> _loadJobsWithLockStatus() async {
    await JobManagementService.loadJobs(context, (VoidCallback callback) {
      if (mounted) {
        setState(() {
          callback();
        });
      }
    }, _jobs);
  }

  Future<void> _loadCurrentUserLocation() async {
    try {
      final hasAccess = await _checkLocationAccess();
      if (hasAccess) {
        loc.Location location = loc.Location();
        loc.LocationData locationData = await location.getLocation();
        setState(() {
          _currentUserLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
      }
    } catch (e) {
      print('Kullanıcı konumu yüklenirken hata: $e');
    }
  }

  Future<bool> _checkLocationAccess() async {
    try {
      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return false;
      }

      loc.PermissionStatus permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return false;
      }
      return true;
    } catch (e) {
      print('Konum erişimi kontrolü hatası: $e');
      return false;
    }
  }

  void _refreshJobs() async {
    await _loadJobsWithLockStatus();
  }

  void _showLocationWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konum Erişimi Gerekli'),
        content: Text('Bu işlemi gerçekleştirmek için konum erişimine ihtiyaç var. Lütfen ayarlardan izin verin.'),
        actions: [
          TextButton(
            child: Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Ayarlar'),
            onPressed: () async {
              Navigator.pop(context);
              await perm.openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void navigateToMapPage(int index) async {
    final hasAccess = await _checkLocationAccess();
    if (!hasAccess) {
      _showLocationWarning();
      return;
    }

    final jobId = _jobs[index]['job_id'] as int;
    final jobArea = await MapsService.getJobArea(jobId);

    LatLng initialCenter;
    List<LatLng> polygonPoints = jobArea;

    if (jobArea.isEmpty) {
      if (_currentUserLocation == null) {
        await _loadCurrentUserLocation();
      }
      initialCenter = _currentUserLocation ?? const LatLng(41.0082397, 28.9783592);
    } else {
      initialCenter = jobArea.first;
    }

    final result = await Navigator.push<(List<LatLng>, bool)>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          jobId: jobId,
          onAreaSelected: (List<LatLng> area, bool isScanned) {
            Navigator.pop(context, (area, isScanned));
          },
        ),
      ),
    );

    if (result != null && result.$1.isNotEmpty) {
      _refreshJobs();
    }
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoadingUserInfo = true;
    });

    try {
      await DatabaseHelper.ensureConnection();
      final userInfo = await DatabaseHelper.getUserById(widget.userId);
      print('Admin kullanıcı bilgileri yüklendi: $userInfo');
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı bilgileri yüklenirken hata: $e')),
      );
    } finally {
      setState(() {
        _isLoadingUserInfo = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController!.dispose();
    jobController.dispose();
    super.dispose();
  }

  void _toggleUserInfoPanel() {
    setState(() {
      _isUserInfoPanelOpen = !_isUserInfoPanelOpen;
    });
  }

  Future<void> _handleJobTap(BuildContext context, int index) async {
    _navigateToJobDetails(index);
  }

  void _navigateToJobDetails(int index) async {
    try {
      await DatabaseHelper.ensureConnection();
      final creatorInfo = await DatabaseHelper.getUserById(_jobs[index]['created_by'] as int);
      final creatorFullName = creatorInfo['full_name']?.toString() ?? 'Bilinmeyen Kullanıcı';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JobDetailsPage(
            jobTitle: _jobs[index]['job_name'],
            description: _jobs[index]['description'],
            createdBy: creatorFullName,
            startTime: _jobs[index]['start_time'],
            endTime: _jobs[index]['end_time'],
            isAdmin: widget.isAdmin,
            jobId: _jobs[index]['job_id'],
            isLocked: _jobs[index]['is_locked'] ?? false,
          ),
        ),
      ).then((_) => _refreshJobs());
    } catch (e) {
      print('Hata: $e');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JobDetailsPage(
            jobTitle: _jobs[index]['job_name'],
            description: _jobs[index]['description'],
            createdBy: 'Bilinmeyen Kullanıcı',
            startTime: _jobs[index]['start_time'],
            endTime: _jobs[index]['end_time'],
            isAdmin: widget.isAdmin,
            jobId: _jobs[index]['job_id'],
            isLocked: _jobs[index]['is_locked'] ?? false,
          ),
        ),
      ).then((_) => _refreshJobs());
    }
  }

  Future<void> _addJob() async {
    if (jobController.text.isNotEmpty) {
      await JobManagementService.addJob(
        context,
        jobController.text,
        widget.userId,
        setState,
        _jobs,
        selectedDate,
        selectedTime,
      );
      jobController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: JobManagementWidgets.buildAppBar(
        context,
        widget.isAdmin,
        _toggleUserInfoPanel,
        _logout,
        _addJob,
        jobController,
      ),
      body: Stack(
        children: [
          Expanded(
            child: JobManagementWidgets.buildJobGrid(
              context,
              _jobs,
              widget.isAdmin,
              widget.userId,
              _animationController!,
              _handleJobTap,
              completeJob,
              assignGroup,
              navigateToMapPage,
              _selectDateTime,
              showUsersInArea,
              selectedDate,
              selectedTime,
              _refreshJobs,
            ),
          ),
          if (_isUserInfoPanelOpen)
            JobManagementWidgets.buildUserInfoPanel(
              context,
              _userInfo,
              _isLoadingUserInfo,
              _toggleUserInfoPanel,
            ),
        ],
      ),
    );
  }

  void completeJob(int index) {
    JobManagementService.completeJob(context, _jobs, index, setState);
  }

  void assignGroup(int index) {
    JobManagementService.assignGroup(context, _jobs, index, widget.isAdmin, widget.userId, setState);
  }

  Future<void> _selectDateTime(BuildContext context, int jobId, int index) async {
    final dateTime = await JobManagementUtils.selectDateTime(context);
    if (dateTime != null) {
      setState(() {
        selectedDate = dateTime['date'];
        selectedTime = dateTime['time'];
      });
      await JobManagementService.updateJobStartTime(context, jobId, selectedDate, selectedTime, setState, _jobs, index);
    }
  }

  void showUsersInArea(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UsersInAreaPage(jobId: _jobs[index]['job_id'])),
    );
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('role');
    await DatabaseHelper.logout();

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  Widget _buildInfoTile(String label, String? value) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_getIconForLabel(label), color: Colors.blue[900]),
        title: Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
        ),
        subtitle: Text(value ?? 'Bilgi Yok', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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
}