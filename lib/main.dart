import 'package:esay/login_page_afad.dart';
import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart'; // DatabaseHelper sınıfı
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esay/admin/admin.dart'; // Admin sayfası (örnek)
import 'package:esay/userpage.dart'; // Kullanıcı sayfası (örnek)
import 'package:location/location.dart' as loc; // location paketi için alias
import 'package:permission_handler/permission_handler.dart' as perm; // permission_handler için alias

void main() async {
  // Flutter framework'ünü başlat
  WidgetsFlutterBinding.ensureInitialized();

  // Veritabanı bağlantısını başlat
  try {
    await DatabaseHelper.openConnection();
    print('Veritabanı bağlantısı başarıyla açıldı.');
  } catch (e) {
    print('Veritabanı bağlantısı açılırken hata oluştu: $e');
  }

  // Uygulamayı başlat
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Başlangıç sayfasını belirleyen asenkron metod
  Future<Widget> _getInitialPage(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    int? userId = prefs.getInt('userId');
    String? role = prefs.getString('role');

    // Oturum açıksa GPS kontrolü yap ve uygun sayfaya yönlendir
    if (isLoggedIn && userId != null) {
      await DatabaseHelper.ensureConnection(); // Bağlantıyı kontrol et
      bool hasGpsAccess = await ensureLocationAccess(context);
      if (hasGpsAccess) {
        if (role == 'admin') {
          return JobManagementPage(userId: userId, isAdmin: true); // Admin sayfası
        } else {
          return UserPage(); // Kullanıcı sayfası
        }
      } else {
        return const LoginPage(); // GPS izni yoksa login sayfasına geri dön
      }
    }
    return const LoginPage(); // Oturum yoksa login sayfası
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İş Yönetimi',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<Widget>(
        future: _getInitialPage(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Yükleme sırasında splash screen göster
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            // Hata durumunda hata mesajı göster
            return Scaffold(
              body: Center(
                child: Text('Hata oluştu: ${snapshot.error}'),
              ),
            );
          }
          return snapshot.data ?? const LoginPage(); // Varsayılan olarak LoginPage
        },
      ),
    );
  }
}

// Splash Screen Widget’ı
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Yükleniyor...', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// GPS ve Konum İzni Kontrol Fonksiyonu
Future<bool> ensureLocationAccess(BuildContext context) async {
  loc.Location location = loc.Location();
  bool serviceEnabled;
  loc.PermissionStatus permissionGranted;

  // 1. GPS servislerini kontrol et
  serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    // GPS kapalıysa uyarı göster ve açma sayfasına yönlendir
    bool opened = await _showGpsWarningDialog(
      context,
      "GPS kapalı. Lütfen GPS'i açın.",
      isServiceWarning: true,
    );
    if (!opened) {
      print("Kullanıcı GPS'i açmayı reddetti.");
      return false;
    }
    // GPS açıldıysa tekrar kontrol et
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      print("GPS hala kapalı.");
      return false;
    }
  }

  // 2. Konum iznini kontrol et ve iste
  permissionGranted = await location.hasPermission();
  if (permissionGranted == loc.PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != loc.PermissionStatus.granted) {
      // İzin reddedildiyse uyarı göster ve ayarlara yönlendir
      await _showGpsWarningDialog(
        context,
        "Konum izni reddedildi. Lütfen izin verin.",
      );
      return false;
    }
  } else if (permissionGranted == loc.PermissionStatus.deniedForever) {
    // Kalıcı reddedildiyse ayarlara yönlendir
    await _showGpsWarningDialog(
      context,
      "Konum izni kalıcı olarak reddedildi. Lütfen ayarlar üzerinden izin verin.",
    );
    return false;
  }

  print("Konum izni ve GPS hazır.");
  return true;
}

// Uyarı diyaloğu göster ve yönlendirme yap
Future<bool> _showGpsWarningDialog(
  BuildContext context,
  String message, {
  bool isServiceWarning = false,
}) async {
  bool actionTaken = false;
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Konum İzni Gerekli"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Diyaloğu kapat
              actionTaken = false;
            },
            child: Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Diyaloğu kapat
              if (isServiceWarning) {
                // GPS açma sayfasına yönlendir
                await loc.Location().requestService();
              } else {
                // Ayarlar sayfasına yönlendir
                await perm.openAppSettings();
              }
              actionTaken = true;
            },
            child: Text("Ayarlara Git"),
          ),
        ],
      );
    },
  );
  return actionTaken;
}