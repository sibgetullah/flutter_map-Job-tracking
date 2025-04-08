import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:postgres/postgres.dart';

class MapsService {
  static PostgreSQLConnection? _connection;

  /// Veritabanı bağlantısını kontrol et ve aç
  static Future<void> ensureConnection() async {
    if (_connection == null || _connection!.isClosed) {
      _connection = PostgreSQLConnection(
        '', // Sunucu adresi
        , // Port numarası
        '', // Veritabanı adı
        username: '', // Kullanıcı adı
        password: '', // Şifre
      );
      await _connection!.open();
    }
  }

static Future<void> addJobArea({
  required int jobId,
  required int areaId,
  required String areaName,
  required List<LatLng> polygonPoints,
  required bool isScanned, // Yeni parametre
}) async {
  await ensureConnection();
  try {
    for (var i = 0; i < polygonPoints.length; i++) {
      final point = polygonPoints[i];
      await _connection!.query(
        '''
        INSERT INTO public.job_areas (job_id, area_id, latitude, longitude, "order", area_name, is_scanned)
        VALUES (@jobId, @areaId, @latitude, @longitude, @order, @areaName, @isScanned)
        ''',
        substitutionValues: {
          'jobId': jobId,
          'areaId': areaId,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'order': i,
          'areaName': areaName,
          'isScanned': isScanned,
        },
      );
    }
    print('✅ Yeni alan eklendi (ID: $areaId, Name: $areaName, Scanned: $isScanned)');
  } catch (e) {
    print('❌ Alan eklenirken hata: $e');
    rethrow;
  }
}

static Future<Map<int, Map<String, dynamic>>> getJobAreasByJobId(int jobId) async {
  await ensureConnection();
  try {
    final result = await _connection!.query(
      '''
      SELECT area_id, latitude, longitude, area_name, is_scanned
      FROM public.job_areas
      WHERE job_id = @jobId
      ORDER BY area_id, "order" ASC
      ''',
      substitutionValues: {'jobId': jobId},
    );

    Map<int, Map<String, dynamic>> areas = {};
    for (var row in result) {
      int areaId = row[0] as int;
      if (!areas.containsKey(areaId)) {
        areas[areaId] = {
          'points': <LatLng>[],
          'name': row[3] as String? ?? 'İsimsiz Alan',
          'isScanned': row[4] as bool? ?? false, // is_scanned ekleniyor
        };
      }
      areas[areaId]!['points'].add(LatLng(row[1] as double, row[2] as double));
    }
    return areas;
  } catch (e) {
    print('Job alanları alınırken hata oluştu: $e');
    return {};
  }
}

static Future<List<LatLng>> getJobArea(int jobId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
        SELECT latitude, longitude
        FROM public.job_areas
        WHERE job_id = @jobId
        ORDER BY "order" ASC
        ''',
        substitutionValues: {'jobId': jobId},
      );

      if (result.isEmpty) {
        print('Job ID $jobId için job_areas bulunamadı.');
        return [];
      }

      return result.map((row) => LatLng(row[0] as double, row[1] as double)).toList();
    } catch (e) {
      print('Job alanı alınırken hata oluştu: $e');
      return [];
    }
  }

  /// Job ID ile ilgili alanı günceller
static Future<void> updateJobArea({
  required int jobId,
  required int areaId,
  required String areaName,
  required List<LatLng> polygonPoints,
}) async {
  await ensureConnection();
  try {
    // Önce eski verileri siliyoruz
    await _connection!.query(
      'DELETE FROM public.job_areas WHERE job_id = @jobId AND area_id = @areaId',
      substitutionValues: {'jobId': jobId, 'areaId': areaId},
    );

    // Yeni verileri ekliyoruz
    for (var i = 0; i < polygonPoints.length; i++) {
      final point = polygonPoints[i];
      await _connection!.query(
        '''
        INSERT INTO public.job_areas (job_id, area_id, latitude, longitude, "order", area_name)
        VALUES (@jobId, @areaId, @latitude, @longitude, @order, @areaName)
        ''',
        substitutionValues: {
          'jobId': jobId,
          'areaId': areaId,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'order': i,
          'areaName': areaName,
        },
      );
    }
    print('✅ Alan güncellendi (ID: $areaId, Name: $areaName)');
  } catch (e) {
    print('❌ Alan güncellenirken hata: $e');
    rethrow;
  }
}

static Future<void> deleteJobArea(int jobId, int areaId) async {
  await ensureConnection();
  try {
    await _connection!.query(
      'DELETE FROM public.job_areas WHERE job_id = @jobId AND area_id = @areaId',
      substitutionValues: {'jobId': jobId, 'areaId': areaId},
    );
    print('✅ Alan silindi (ID: $areaId)');
  } catch (e) {
    print('❌ Alan silinirken hata: $e');
    rethrow;
  }
}

  // -------------------- User Locations --------------------

  /// Kullanıcı ID'sine göre konum bilgilerini getir
  static Future<List<Map<String, dynamic>>> getUserLocations(int userId) async {
    await ensureConnection();

    try {
      final result = await _connection!.query(
        '''
        SELECT id, user_id, latitude, longitude, recorded_at, geom, is_active
        FROM public.user_locations
        WHERE user_id = @userId
        ORDER BY recorded_at DESC
        LIMIT 1  -- En son konumu getir
        ''',
        substitutionValues: {'userId': userId},
      );

      return result.map((row) {
        return {
          'id': row[0],
          'user_id': row[1],
          'latitude': row[2],
          'longitude': row[3],
          'recorded_at': row[4],
          'geom': row[5],
          'is_active': row[6],
        };
      }).toList();
    } catch (e) {
      print('Kullanıcı konum bilgileri alınırken hata oluştu: $e');
      return [];
    }
  }
static Future<LatLng?> getCurrentUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Konum alınırken hata oluştu: $e');
      return null;
    }
  }
  /// Kullanıcı konumunu veritabanına kaydet
  static Future<void> addUserLocation({
    required int userId,
    required double latitude,
    required double longitude,
  }) async {
    await ensureConnection();

    try {
      await _connection!.query(
        '''
        INSERT INTO public.user_locations (user_id, latitude, longitude, recorded_at, is_active)
        VALUES (@userId, @latitude, @longitude, @recordedAt, @isActive)
        ''',
        substitutionValues: {
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'recordedAt': DateTime.now(),
          'isActive': true,
        },
      );

      print('Kullanıcı konumu başarıyla kaydedildi.');
    } catch (e) {
      print('Kullanıcı konumu kaydedilirken hata oluştu: $e');
      rethrow;
    }
  }

  /// Bir işin alanındaki kullanıcıları getir
  static Future<List<Map<String, dynamic>>> getUsersInJobArea(int jobId) async {
    await ensureConnection();

    try {
      // İşin alanını (poligon) getir
      final polygonPoints = await getJobArea(jobId);
      if (polygonPoints.isEmpty) {
        return [];
      }

      // Poligonu PostGIS formatına çevir
      final polygonText =
          'POLYGON((${polygonPoints.map((p) => "${p.longitude} ${p.latitude}").join(",")},${polygonPoints.first.longitude} ${polygonPoints.first.latitude}))';

      // Alandaki kullanıcıları sorgula
      final result = await _connection!.query(
        '''
        SELECT DISTINCT ul.user_id, u.full_name, g.group_name
        FROM public.user_locations ul
        JOIN public.users u ON ul.user_id = u.user_id
        LEFT JOIN public.user_groups ug ON ul.user_id = ug.user_id
        LEFT JOIN public.groups g ON ug.group_id = g.group_id
        WHERE ST_Contains(
          ST_GeomFromText(@polygonText, 4326),
          ST_SetSRID(ST_MakePoint(ul.longitude, ul.latitude), 4326)
        )
        AND ul.is_active = true
        ORDER BY ul.user_id
        ''',
        substitutionValues: {
          'polygonText': polygonText,
        },
      );

      return result.map((row) {
        return {
          'user_id': row[0],
          'full_name': row[1],
          'group_name': row[2] ?? 'Grup Yok',
          'latitude': null, // Harita için konumları ayrı bir sorguyla alacağız
          'longitude': null,
        };
      }).toList();
    } catch (e) {
      print('Alandaki kullanıcılar alınırken hata oluştu: $e');
      return [];
    }
  }

  /// Bir işin alanındaki kullanıcıların son konumlarını getir
  static Future<List<Map<String, dynamic>>> getUsersInJobAreaWithLocations(
      int jobId) async {
    final usersInArea = await getUsersInJobArea(jobId);
    for (var user in usersInArea) {
      final locations = await getUserLocations(user['user_id']);
      if (locations.isNotEmpty) {
        user['latitude'] = locations.first['latitude'];
        user['longitude'] = locations.first['longitude'];
      }
    }
    return usersInArea;
  }
}
