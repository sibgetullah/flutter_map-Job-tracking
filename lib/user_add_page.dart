import 'package:flutter/material.dart';

class UserAddPage extends StatelessWidget {
  final int userId;
  final bool isAdmin;

  UserAddPage({required this.userId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kişi Ekle',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0054A6),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Kişi Ekleme Sayfası',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0054A6),
                ),
              ),
              SizedBox(height: 20),
              Text('Buraya kişi ekleme formu eklenecek.'),
            ],
          ),
        ),
      ),
    );
  }
}