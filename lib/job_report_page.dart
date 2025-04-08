import 'dart:io';
import 'package:esay/StoragePermissionService.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class ReportPages {
  static Future<void> generateFullReport(
    BuildContext context, {
    required String jobTitle,
    required String description,
    required String createdBy,
    required DateTime? startTime,
    required int jobId,
    required List<Map<String, dynamic>> users,
    required Map<String, bool> userSelections,
    required List<Map<String, dynamic>> taskEntries,
    required List<Map<String, dynamic>> extraTaskEntries,
    required List<Map<String, dynamic>> attendedUsersLog,
  }) async {
    if (!await StoragePermissionService.checkAndRequestStorageAccess(context)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Depolama izni verilmeden rapor alınamaz.')));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Rapor'];

    sheet.appendRow(['İş Adı', jobTitle]);
    sheet.appendRow(['Açıklama', description]);
    sheet.appendRow(['Oluşturan', createdBy]);
    sheet.appendRow(['Başlangıç Tarihi', startTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(startTime) : 'Belirtilmemiş']);
    sheet.appendRow([]);

    sheet.appendRow(['Atanan Kullanıcılar']);
    sheet.appendRow(['Ad Soyad', 'Katılım Durumu']);
    for (var user in users) {
      final userId = user['user_id'].toString();
      sheet.appendRow([user['full_name'], userSelections[userId] == true ? 'Katıldı' : 'Katılmadı']);
    }
    sheet.appendRow([]);

    sheet.appendRow(['Atanan Dış Görevliler']);
    sheet.appendRow(['Tip/Kişi Sayısı veya Ad', 'TC Kimlik No', 'Oluşturulma Zamanı']);
    for (var entry in taskEntries) {
      sheet.appendRow(['${entry['count']} kişi (${entry['type']})', '', DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'])]);
    }
    for (var extraEntry in extraTaskEntries) {
      sheet.appendRow([extraEntry['team_name'], extraEntry['tc_kimlik_no'], DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'])]);
    }
    sheet.appendRow([]);

    sheet.appendRow(['Giriş Zamanları']);
    sheet.appendRow(['Ad Soyad', 'Giriş Zamanı']);
    for (var log in attendedUsersLog) {
      final user = users.firstWhere((u) => u['user_id'] == log['user_id'], orElse: () => <String, Object>{'full_name': 'Bilinmeyen Kullanıcı'});
      sheet.appendRow([user['full_name'], DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(log['entry_time']))]);
    }
    sheet.appendRow([]);

    sheet.appendRow(['Dış Görevliler Zamanları']);
    sheet.appendRow(['Tip/Kişi Sayısı veya Ad', 'TC Kimlik No', 'Zaman']);
    for (var entry in taskEntries) {
      sheet.appendRow(['${entry['count']} kişi (${entry['type']})', '', DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'])]);
    }
    for (var extraEntry in extraTaskEntries) {
      sheet.appendRow([extraEntry['team_name'], extraEntry['tc_kimlik_no'], DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'])]);
    }

    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/Tamaminin_Raporu_${jobId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    await OpenFile.open(filePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tamamının raporu telefona indirildi: $filePath')));
  }

  static Future<void> generateAttendedUsersLogReport(
    BuildContext context, {
    required String jobTitle,
    required String description,
    required String createdBy,
    required DateTime? startTime,
    required List<Map<String, dynamic>> attendedUsersLog,
    required List<Map<String, dynamic>> users,
  }) async {
    if (!await StoragePermissionService.checkAndRequestStorageAccess(context)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Depolama izni verilmeden rapor alınamaz.')));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Giriş Zamanları'];

    sheet.appendRow(['İş Adı', jobTitle]);
    sheet.appendRow(['Açıklama', description]);
    sheet.appendRow(['Oluşturan', createdBy]);
    sheet.appendRow(['Başlangıç Tarihi', startTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(startTime) : 'Belirtilmemiş']);
    sheet.appendRow([]);

    sheet.appendRow(['Ad Soyad', 'Giriş Zamanı']);
    for (var log in attendedUsersLog) {
      final user = users.firstWhere((u) => u['user_id'] == log['user_id'], orElse: () => <String, Object>{'full_name': 'Bilinmeyen Kullanıcı'});
      sheet.appendRow([user['full_name'], DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(log['entry_time']))]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/Giris_Zamanlari_Raporu_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    try {
      await OpenFile.open(filePath);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Giriş zamanları raporu kaydedildi: $filePath\nDosyayı cihazınızdaki dosya yöneticisi ile bulabilirsiniz.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor kaydedildi ancak açılamadı: $filePath\nHata: $e')));
    }
  }

  static Future<void> generateAssignedUsersReport(
    BuildContext context, {
    required String jobTitle,
    required String description,
    required String createdBy,
    required DateTime? startTime,
    required int jobId,
    required List<Map<String, dynamic>> users,
    required Map<String, bool> userSelections,
  }) async {
    if (!await StoragePermissionService.checkAndRequestStorageAccess(context)) {
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Atanan Kullanıcılar'];

    sheet.appendRow(['İş Adı', jobTitle]);
    sheet.appendRow(['Açıklama', description]);
    sheet.appendRow(['Oluşturan', createdBy]);
    sheet.appendRow(['Başlangıç Tarihi', startTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(startTime) : 'Belirtilmemiş']);
    sheet.appendRow([]);

    sheet.appendRow(['Ad Soyad', 'Katılım Durumu']);
    for (var user in users) {
      final userId = user['user_id'].toString();
      sheet.appendRow([user['full_name'], userSelections[userId] == true ? 'Katıldı' : 'Katılmadı']);
    }

    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/Atanan_Kullanicilar_Raporu_${jobId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    await OpenFile.open(filePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Atanan kullanıcılar raporu telefona indirildi: $filePath')));
  }

  static Future<void> generateAssignedExtraTasksReport(
    BuildContext context, {
    required String jobTitle,
    required String description,
    required String createdBy,
    required DateTime? startTime,
    required List<Map<String, dynamic>> taskEntries,
    required List<Map<String, dynamic>> extraTaskEntries,
  }) async {
    if (!await StoragePermissionService.checkAndRequestStorageAccess(context)) {
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Atanan Dış Görevliler'];

    sheet.appendRow(['İş Adı', jobTitle]);
    sheet.appendRow(['Açıklama', description]);
    sheet.appendRow(['Oluşturan', createdBy]);
    sheet.appendRow(['Başlangıç Tarihi', startTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(startTime) : 'Belirtilmemiş']);
    sheet.appendRow([]);

    sheet.appendRow(['Tip/Kişi Sayısı veya Ad', 'TC Kimlik No', 'Oluşturulma Zamanı']);
    for (var entry in taskEntries) {
      sheet.appendRow(['${entry['count']} kişi (${entry['type']})', '', DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'])]);
    }
    for (var extraEntry in extraTaskEntries) {
      sheet.appendRow([extraEntry['team_name'], extraEntry['tc_kimlik_no'], DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'])]);
    }

    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/Atanan_Dis_Gorevliler_Raporu_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    await OpenFile.open(filePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Atanan dış görevliler raporu telefona indirildi: $filePath')));
  }

  static Future<void> generateExtraTasksLogReport(
    BuildContext context, {
    required String jobTitle,
    required String description,
    required String createdBy,
    required DateTime? startTime,
    required List<Map<String, dynamic>> taskEntries,
    required List<Map<String, dynamic>> extraTaskEntries,
  }) async {
    if (!await StoragePermissionService.checkAndRequestStorageAccess(context)) {
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Dış Görevliler Zamanları'];

    sheet.appendRow(['İş Adı', jobTitle]);
    sheet.appendRow(['Açıklama', description]);
    sheet.appendRow(['Oluşturan', createdBy]);
    sheet.appendRow(['Başlangıç Tarihi', startTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(startTime) : 'Belirtilmemiş']);
    sheet.appendRow([]);

    sheet.appendRow(['Tip/Kişi Sayısı veya Ad', 'TC Kimlik No', 'Zaman']);
    for (var entry in taskEntries) {
      sheet.appendRow(['${entry['count']} kişi (${entry['type']})', '', DateFormat('dd/MM/yyyy HH:mm').format(entry['created_at'])]);
    }
    for (var extraEntry in extraTaskEntries) {
      sheet.appendRow([extraEntry['team_name'], extraEntry['tc_kimlik_no'], DateFormat('dd/MM/yyyy HH:mm').format(extraEntry['created_at'])]);
    }

    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/Dis_Gorevliler_Zamanlari_Raporu_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    await OpenFile.open(filePath);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dış görevliler zamanları raporu telefona indirildi: $filePath')));
  }
}