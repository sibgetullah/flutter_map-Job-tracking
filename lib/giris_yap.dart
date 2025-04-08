import 'package:flutter/material.dart';

class GirisYapPage extends StatefulWidget {
  @override
  _GirisYapPageState createState() => _GirisYapPageState();
}

class _GirisYapPageState extends State<GirisYapPage> {
  final TextEditingController _tcKimlikController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giriş Yap'),
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
              controller: _sifreController,
              decoration: InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Giriş yapma işlemleri burada gerçekleştirilecek
                print(
                    'Giriş yap: ${_tcKimlikController.text}, ${_sifreController.text}');
              },
              child: Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
