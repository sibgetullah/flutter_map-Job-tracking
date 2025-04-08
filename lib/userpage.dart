import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:esay/login_page_afad.dart';
import 'package:esay/style/color.dart';
import 'package:esay/style/widget.dart';
import 'package:esay/user_id.dart';
import 'package:esay/connect_afad.dart';
import 'jobpage.dart';

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic> _userInfo = {};
  bool _isUserInfoPanelOpen = false;
  bool _isLoadingUserInfo = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      await DatabaseHelper.openConnection();
      final jobs = await DatabaseHelper.getIncompleteJobs();
      setState(() {
        _jobs = jobs;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşler yüklenirken bir hata oluştu: $e')),
      );
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Tarih Yok';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildInfoTile(String label, String? value) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          _getIconForLabel(label),
          color: Colors.blue[900],
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        subtitle: Text(
          value ?? 'Bilgi Yok',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
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

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoadingUserInfo = true;
    });

    try {
      await DatabaseHelper.openConnection();
      final userInfo = await DatabaseHelper.getUserById(loggedInUserId);
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı bilgileri yüklenirken bir hata oluştu: $e')),
      );
    } finally {
      setState(() {
        _isLoadingUserInfo = false;
      });
    }
  }

  void _logout() async {
    await DatabaseHelper.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _navigateToJobDetails(BuildContext context, Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsPage(
          jobTitle: job['job_name'],
          description: job['description'],
          createdBy: "Kullanıcı ${job['created_by']}",
          startTime: job['start_time'],
          endTime: job['end_time'],
          isAdmin: false,
          onEdit: null,
          onDelete: null,
          jobId: job['job_id'],
          isLocked: false, // Kullanıcı panelinde kilit yok
        ),
      ),
    );
  }

  void _toggleUserInfoPanel() async {
    if (!_isUserInfoPanelOpen) {
      await _loadUserInfo();
    }
    setState(() {
      _isUserInfoPanelOpen = !_isUserInfoPanelOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kullanıcı Paneli',
          style: TextStyle(color: afadWhite),
        ),
        backgroundColor: afadDarkBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: afadWhite),
            onPressed: _toggleUserInfoPanel,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: afadWhite),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Stack(
        children: [
          _jobs.isEmpty
              ? Center(
                  child: Text(
                    'Tamamlanmamış iş bulunmamaktadır.',
                    style: subtitleStyle,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) {
                    final job = _jobs[index];
                    return GestureDetector(
                      onTap: () => _navigateToJobDetails(context, job),
                      child: Card(
                        elevation: 8.0,
                        shadowColor: Colors.black.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [afadDarkBlue, afadLightBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    job['job_name'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: afadWhite,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Başlangıç: ${formatDate(job['start_time'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: afadWhite.withOpacity(0.8),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  if (job['end_time'] != null)
                                    Text(
                                      'Bitiş: ${formatDate(job['end_time'])}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: afadWhite.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          if (_isUserInfoPanelOpen)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: afadWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kullanıcı Bilgileri',
                          style: titleStyle,
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: afadDarkBlue),
                          onPressed: _toggleUserInfoPanel,
                        ),
                      ],
                    ),
                    Divider(
                      color: afadDarkBlue,
                      thickness: 1,
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: _isLoadingUserInfo
                          ? Center(
                              child: CircularProgressIndicator(
                                color: afadDarkBlue,
                              ),
                            )
                          : ListView(
                              children: [
                                _buildInfoTile('Ad Soyad', _userInfo['full_name']),
                                _buildInfoTile('Unvan', _userInfo['title']),
                                _buildInfoTile('Rol', _userInfo['role']),
                                _buildInfoTile('Kan Grubu', _userInfo['kan_grubu']),
                                _buildInfoTile('Email', _userInfo['email']),
                                _buildInfoTile('Telefon', _userInfo['gsm_tel']),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}