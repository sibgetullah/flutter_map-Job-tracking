import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as perm;

class LocationService {
  static Future<bool> checkAndRequestLocationAccess(BuildContext context) async {
    try {
      // Konum servislerinin açık olup olmadığını kontrol et
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();

      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          await _showSettingsDialog(
            context,
            title: 'Konum Servisi Kapalı',
            message: 'Lütfen cihaz ayarlarından GPS’i açın.',
          );
          return false;
        }
      }

      // Konum izni kontrolü
      var status = await perm.Permission.location.status;
      if (status.isDenied) {
        status = await perm.Permission.location.request();
        if (status.isDenied) {
          await _showSettingsDialog(
            context,
            title: 'Konum İzni Gerekli',
            message: 'Konum izni olmadan uygulama çalışamaz.',
          );
          return false;
        }
      }

      // Kalıcı olarak reddedilmişse ayarlara yönlendir
      if (status.isPermanentlyDenied) {
        await _showSettingsDialog(
          context,
          title: 'Konum İzni Reddedildi',
          message: 'Lütfen ayarlardan konum izni verin.',
        );
        return false;
      }

      return true;
    } catch (e) {
      print('Konum izni hatası: $e');
      return false;
    }
  }

  static Future<void> _showSettingsDialog(BuildContext context,
      {required String title, required String message}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Ayarlar'),
            onPressed: () async {
              Navigator.pop(context);
              await perm.openAppSettings();
            },
          ),
        ],
      ),
    );
  }
}
