import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart'; // Veritabanı bağlantısı için
import 'user_id.dart'; // Global değişkenler için
import 'admin/job_management_styles.dart';


class UserInfoPage extends StatefulWidget {
  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  Map<String, dynamic> _userInfo = {};
  bool _isLoading = true;

  Future<void> _loadUserInfo() async {
    try {
      await DatabaseHelper.ensureConnection(); // Bağlantının açık olduğundan emin ol
      final userInfo = await DatabaseHelper.getUserById(loggedInUserId); // Giriş yapan kullanıcının bilgilerini getir
      setState(() {
        _userInfo = userInfo;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı bilgileri yüklenirken bir hata oluştu: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo(); // Sayfa açıldığında kullanıcı bilgilerini yükle
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
          color: JobManagementStyles.darkBlue,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: JobManagementStyles.darkBlue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kullanıcı Bilgileri',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: JobManagementStyles.darkBlue,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: JobManagementStyles.darkBlue,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildInfoTile('Ad Soyad', _userInfo['full_name']),
                _buildInfoTile('Unvan', _userInfo['title']),
                _buildInfoTile('Rol', _userInfo['role']),
                _buildInfoTile('Kan Grubu', _userInfo['kan_grubu']),
                _buildInfoTile('Email', _userInfo['email']),
                _buildInfoTile('Telefon', _userInfo['gsm_tel']),
              ],
            ),
    );
  }
}