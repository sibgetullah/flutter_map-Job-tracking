import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:esay/connect_afad.dart';

class QrCodeEntryPage extends StatefulWidget {
  final int jobId;

  const QrCodeEntryPage({super.key, required this.jobId});

  @override
  State<QrCodeEntryPage> createState() => _QrCodeEntryPageState();
}

class _QrCodeEntryPageState extends State<QrCodeEntryPage> {
  MobileScannerController cameraController = MobileScannerController();
  String? scannedTcKimlikNo;
  bool isAssigned = false;
  bool isScanning = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstWhere(
      (b) => b.rawValue != null,
      orElse: () => Barcode(rawValue: null),
    );

    if (!isScanning || barcode.rawValue == null) return;

    final tcKimlikNo = barcode.rawValue!;
    setState(() {
      scannedTcKimlikNo = tcKimlikNo;
      isScanning = false;
    });

    try {
      // TC kimlik numarasından user_id bul
      final userId = await DatabaseHelper.getUserIdByTcKimlikNo(tcKimlikNo);
      if (userId != null) {
        // assigned_users'dan kontrol et
        final assignedUsers = await DatabaseHelper.getAssignedUsers(widget.jobId);
        if (assignedUsers.contains(userId)) {
          // Kullanıcıyı attended_users listesine ekle
          await DatabaseHelper.addAttendedUser(widget.jobId, userId);
          
          setState(() {
            isAssigned = true;
          });
          print('User ID $userId assigned_users\'da bulundu ve attended_users\'a eklendi');
        } else {
          setState(() {
            isAssigned = false;
          });
          print('User ID $userId assigned_users\'da bulunamadı: $assignedUsers');
        }
      } else {
        setState(() {
          isAssigned = false;
        });
        print('TC Kimlik No $tcKimlikNo ile kullanıcı bulunamadı.');
      }
    } catch (e) {
      print('QR kod işleme hatası: $e');
      setState(() {
        isAssigned = false;
      });
    } finally {
      await cameraController.stop();
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAssigned ? 'Başarılı' : 'Hata'),
        content: Text(
          isAssigned
              ? 'Size Atanan İş Bulundu Otomatik Eklendiniz.'
              : 'Size Atanan İş Bulunamadı Manuel Ekleyiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, isAssigned);
              setState(() {
                isScanning = true;
                scannedTcKimlikNo = null;
                isAssigned = false;
              });
              cameraController.start();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod ile Giriş', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0054A6),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              errorBuilder: (context, exception, child) {
                return const Center(
                  child: Text(
                    'Kamera hatası: Lütfen izinleri kontrol edin.',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (scannedTcKimlikNo != null)

                  if (scannedTcKimlikNo != null)
                    isAssigned
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 50)
                        : const Text(
                            'Kullanıcı  bulunamadı.',
                            style: TextStyle(fontSize: 16, color: Colors.red),
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