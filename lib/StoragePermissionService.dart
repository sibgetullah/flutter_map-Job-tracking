import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

class StoragePermissionService {
  static Future<bool> checkAndRequestStorageAccess(BuildContext context) async {
    try {
      // Depolama izni durumu kontrolü (READ_EXTERNAL_STORAGE için)
      var storageStatus = await perm.Permission.storage.status;

      if (storageStatus.isDenied) {
        storageStatus = await perm.Permission.storage.request();
        if (storageStatus.isDenied) {
          await _showSettingsDialog(
            context,
            title: 'Depolama İzni Gerekli',
            message: 'Raporları Downloads klasörüne kaydetmek için depolama iznine ihtiyacımız var.',
          );
          return false;
        }
      }

      if (storageStatus.isPermanentlyDenied) {
        await _showSettingsDialog(
          context,
          title: 'Depolama İzni Reddedildi',
          message: 'Lütfen ayarlar kısmından depolama iznini manuel olarak verin.',
        );
        return false;
      }

      return storageStatus.isGranted;
    } catch (e) {
      print('Depolama izni kontrolü sırasında hata: $e');
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