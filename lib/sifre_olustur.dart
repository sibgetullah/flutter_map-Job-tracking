import 'package:flutter/material.dart';

class SifreOlusturPage extends StatefulWidget {
  @override
  _SifreOlusturPageState createState() => _SifreOlusturPageState();
}

class _SifreOlusturPageState extends State<SifreOlusturPage> {
  final TextEditingController _tcKimlikController = TextEditingController();
  final TextEditingController _mailController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  final TextEditingController _sifreTekrarController = TextEditingController();

  void _sifreOlustur() {
    if (_sifreController.text == _sifreTekrarController.text) {
      // Şifre oluşturma işlemleri burada gerçekleştirilecek
      print(
          'Şifre oluşturuldu: ${_tcKimlikController.text}, ${_mailController.text}, ${_sifreController.text}');
    } else {
      _showAlertDialog(
          context, 'Hata', 'Şifreler uyuşmuyor. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _showAlertDialog(
      BuildContext context, String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Şifre Oluştur'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tcKimlikController,
              decoration: InputDecoration(labelText: 'TC Kimlik'),
              keyboardType: TextInputType.number,
              maxLength: 11,
            ),
            TextField(
              controller: _mailController,
              decoration: InputDecoration(labelText: 'Mail Adresi'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _sifreController,
              decoration: InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            TextField(
              controller: _sifreTekrarController,
              decoration: InputDecoration(labelText: 'Şifre Tekrar'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sifreOlustur,
              child: Text('Şifre Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
