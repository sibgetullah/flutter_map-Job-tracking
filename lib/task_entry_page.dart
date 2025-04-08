import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart';

class TaskEntryPage extends StatefulWidget {
  final int jobId;

  TaskEntryPage({required this.jobId});

  @override
  _TaskEntryPageState createState() => _TaskEntryPageState();
}

class _TaskEntryPageState extends State<TaskEntryPage> {
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  Future<void> _saveEntry() async {
    String countText = _countController.text.trim();
    String type = _typeController.text.trim();

    if (countText.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm alanları doldurun.')),
      );
      return;
    }

    int count = int.tryParse(countText) ?? 0;
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geçerli bir sayı girin.')),
      );
      return;
    }

    try {
      await DatabaseHelper.saveTaskEntry(widget.jobId, count, type);
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
          'Görevli Giriş Kayıt',
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
              controller: _countController,
              decoration: InputDecoration(
                labelText: 'Sayı',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _typeController,
              decoration: InputDecoration(
                labelText: 'Tür',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveEntry,
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