import 'package:flutter/material.dart';
import 'package:esay/admin/admin.dart'; // JobManagementPage
import 'package:esay/user_add_page.dart'; // UserAddPage

class AdminHomePage extends StatelessWidget {
  final int userId;
  final bool isAdmin;

  AdminHomePage({required this.userId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Yönetici Ana Sayfası',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0054A6), // AFAD mavisi
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Kişi Ekleme Kartı
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserAddPage(
                          userId: userId,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 250,
                    height: 150,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add,
                          size: 50,
                          color: Color(0xFF0054A6),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Kişi Ekle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0054A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // İş Ekleme Kartı
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobManagementPage(
                          userId: userId,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 250,
                    height: 150,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work,
                          size: 50,
                          color: Color(0xFF0054A6),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'İş Ekle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0054A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}