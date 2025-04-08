import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart';

class ExtraTaskEntryPage extends StatefulWidget {
  final int jobId;

  ExtraTaskEntryPage({required this.jobId});

  @override
  _ExtraTaskEntryPageState createState() => _ExtraTaskEntryPageState();
}

class _ExtraTaskEntryPageState extends State<ExtraTaskEntryPage> {
  final TextEditingController _tcController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();

  Future<void> _saveExtraEntry() async {
    String tc = _tcController.text.trim();
    String team = _teamController.text.trim();
    String phone = _phoneController.text.trim();
    String bloodGroup = _bloodGroupController.text.trim();

    if (tc.isEmpty || team.isEmpty || phone.isEmpty || bloodGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm alanları doldurun.')),
      );
      return;
    }

    if (tc.length != 11 || int.tryParse(tc) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geçerli bir TC Kimlik No girin (11 hane).')),
      );
      return;
    }

    try {
      await DatabaseHelper.saveExtraTaskEntry(widget.jobId, tc, team, phone, bloodGroup);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarıyla eklendi.')),
      );
      Navigator.pop(context); // Geri dön
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt eklenirken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ek Görevli Giriş Kayıt',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0054A6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tcController,
              decoration: InputDecoration(
                labelText: 'TC Kimlik No',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 11,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _teamController,
              decoration: InputDecoration(
                labelText: 'Ekip Adı',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _bloodGroupController,
              decoration: InputDecoration(
                labelText: 'Kan Grubu',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveExtraEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0054A6),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  'Kayıt',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}