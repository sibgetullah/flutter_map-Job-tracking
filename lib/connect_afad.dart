import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_id.dart';
import 'dart:async';

class DatabaseHelper {
  static PostgreSQLConnection? _connection;
  static bool _isConnected = false;
  static Timer? _keepAliveTimer;
  

  /// Bağlantıyı kontrol eder ve gerekirse açar
  static Future<void> ensureConnection() async {
    if (!_isConnected || _connection == null || _connection!.isClosed) {
      await openConnection();
    }
  }

  /// Veritabanı bağlantısını açar
  static Future<void> openConnection() async {
    try {
      _connection = PostgreSQLConnection(
        '', // Sunucu adresi
        , // Port numarası
        '', // Veritabanı adı
        username: '', // Kullanıcı adı
        password: '', // Şifre
        timeoutInSeconds: 1800, // 30 dakika
        queryTimeoutInSeconds: 1800
      );

      await _connection!.open();
      _isConnected = true;
      print('Veritabanı bağlantısı başarılı.');
      _startKeepAlive();
    } catch (e) {
      _isConnected = false;
      _connection = null;
      print('Veritabanı bağlantısı hatası: ');
      throw Exception('Veritabanına bağlanılamadı: ');
    }
  }

  /// Bağlantıyı canlı tutar ve 30 dakikada bir kapatır
  static void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 25), (timer) async {
      await keepAlive();
    });
    Timer(const Duration(minutes: 30), () async {
      await closeConnection();
      print('30 dakika doldu, bağlantı kapatıldı.');
    });
  }

  /// Bağlantıyı canlı tutmak için güvenli bir metod
  static Future<void> keepAlive() async {
    await ensureConnection();
    try {
      if (_connection != null && !_connection!.isClosed) {
        await _connection!.query('SELECT 1');
        print('Bağlantı canlı tutuldu.');
      }
    } catch (e) {
      print('Keep-alive sorgusu başarısız: $e');
      _isConnected = false;
      await ensureConnection();
    }
  }
/// Tüm grupları çeker
  static Future<List<Map<String, dynamic>>> getAllGroups() async {
    await ensureConnection();
    try {
      final result = await _connection!.query('SELECT group_id, group_name FROM public.groups');
      return result.map((row) => {'group_id': row[0] as int, 'group_name': row[1] as String}).toList();
    } catch (e) {
      print('Gruplar çekilirken hata: $e');
      return [];
    }
  }
 
  /// Belirli bir işe atanmış kullanıcıları çeker (group_id ile birlikte)
  static Future<List<Map<String, dynamic>>> getUserNamesFromAssignedUsers(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT u.user_id, COALESCE(u.full_name, 'Bilinmiyor') AS full_name, u.group_id
        FROM public.users u
        WHERE u.user_id IN (SELECT unnest(j.assigned_users) FROM public.jobs j WHERE j.job_id = @jobId)
        ''',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => {
        'user_id': row[0] as int,
        'full_name': row[1] as String,
        'group_id': row[2] as int?,
      }).toList();
    } catch (e) {
      print('Kullanıcı isimleri getirilirken hata oluştu: $e');
      return [];
    }
  }
  /// Veritabanı bağlantısını kapatır
  static Future<void> closeConnection() async {
    if (_isConnected && _connection != null && !_connection!.isClosed) {
      _keepAliveTimer?.cancel();
      await _connection!.close();
      _isConnected = false;
      _connection = null;
      print('Veritabanı bağlantısı kapatıldı.');
    }
  }

  /// Veritabanı bağlantısının açık olup olmadığını kontrol eder
  static bool get isConnected => _isConnected && _connection != null && !_connection!.isClosed;

/// Kullanıcı girişi kontrolü yapar
  static Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    await ensureConnection();
    try {
      // Kullanıcıyı kullanıcı adına göre al
      final result = await _connection!.query(
        'SELECT user_id, username, password_hash, role FROM users WHERE username = @username',
        substitutionValues: {'username': username},
      );

      if (result.isNotEmpty) {
        final storedHash = result[0][2] as String; // password_hash
        final userId = result[0][0] as int;
        final role = result[0][3] as String;

        // Şifreyi doğrula
        if (BCrypt.checkpw(password, storedHash)) {
          return {
            'user_id': userId,
            'username': username,
            'role': role,
          };
        } else {
          print('Şifre eşleşmedi.');
          return null;
        }
      }
      print('Kullanıcı bulunamadı.');
      return null;
    } catch (e) {
      print('Giriş hatası: $e');
      return null;
    }
  }

  /// Şifreyi sıfırlar
  static Future<bool> resetPassword({
    required String tc,
    required String username,
    required String newPassword,
  }) async {
    await ensureConnection();
    try {
      // Kullanıcıyı TC ve kullanıcı adına göre kontrol et
      final result = await _connection!.query(
        'SELECT user_id FROM public.users WHERE tc_kimlik_no = @tc AND username = @username',
        substitutionValues: {
          'tc': tc,
          'username': username,
        },
      );

      if (result.isEmpty) {
        return false; // Kullanıcı bulunamadı
      }

      // Yeni şifreyi hashle
      final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());

      // Şifreyi güncelle
      await _connection!.execute(
        'UPDATE public.users SET password_hash = @password WHERE tc_kimlik_no = @tc AND username = @username',
        substitutionValues: {
          'password': hashedPassword,
          'tc': tc,
          'username': username,
        },
      );

      return true;
    } catch (e) {
      print('Şifre sıfırlama hatası: $e');
      rethrow;
    }
  }

  static Future<int?> getUserIdByTcKimlikNo(String tcKimlikNo) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT user_id 
        FROM public.users 
        WHERE tc_kimlik_no = @tcKimlikNo
        ''',
        substitutionValues: {
          'tcKimlikNo': tcKimlikNo,
        },
      );
      return result.isNotEmpty ? result[0][0] as int : null;
    } catch (e) {
      print('TC kimlik no ile kullanıcı bulma hatası: $e');
      return null;
    }
  }
  
static Future<void> updateJobDescription(int jobId, String description) async {
  await ensureConnection();
  try {
    await _connection!.query(
      '''
      UPDATE public.jobs 
      SET description = @description
      WHERE job_id = @jobId
      ''',
      substitutionValues: {
        'description': description,
        'jobId': jobId,
      },
    );
    print('Job description updated successfully for job_id: $jobId');
  } catch (e) {
    print('Error updating job description: $e');
    throw Exception('Failed to update job description: $e');
  }
}

  /// İşleri yüklerken kilit durumlarını da al
  static Future<List<Map<String, dynamic>>> loadJobs() async {
    await ensureConnection();
    try {
      final result = await _connection!.query('''
        SELECT 
          job_id, job_name, description, created_by, created_at, 
          start_time, end_time, assigned_groups, assigned_users, 
          is_assignment_completed, attended_users, job_area, 
          participation_status, is_locked, lock_password
        FROM public.jobs
      ''');

      return result.map((row) {
        return {
          'job_id': row[0] as int,
          'job_name': row[1] as String,
          'description': row[2] as String?,
          'created_by': row[3] as int,
          'created_at': row[4] as DateTime?,
          'start_time': row[5] as DateTime?,
          'end_time': row[6] as DateTime?,
          'assigned_groups': row[7] as List<int>?,
          'assigned_users': row[8] as List<int>?,
          'is_assignment_completed': row[9] as bool? ?? false,
          'attended_users': row[10] as List<int>?,
          'job_area': row[11] as String?,
          'participation_status': row[12] as String?,
          'is_locked': row[13] as bool? ?? false,
          'lock_password': row[14] as String?,
        };
      }).toList();
    } catch (e) {
      print('İşler yüklenirken hata: $e');
      return [];
    }
  }
  static Future<PostgreSQLConnection?> getConnection() async {
    try {
      if (_connection == null || _connection!.isClosed) {
        await openConnection();
      }
      return _connection;
    } catch (e) {
      print('Bağlantı alınamadı: $e');
      return null;
    }
  }

  static Future<int> createJob(
    String jobName,
    int createdBy, {
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool isLocked = false,
    String? lockPassword,
  }) async {
    await ensureConnection();
    try {
      final result = await _connection!.query('''
        INSERT INTO public.jobs (
          job_name, description, created_by, 
          start_time, end_time, is_locked, lock_password
        ) 
        VALUES (
          @jobName, @description, @createdBy, 
          @startTime, @endTime, @isLocked, @lockPassword
        )
        RETURNING job_id
      ''', substitutionValues: {
        'jobName': jobName,
        'description': description,
        'createdBy': createdBy,
        'startTime': startTime,
        'endTime': endTime,
        'isLocked': isLocked,
        'lockPassword': lockPassword,
      });

      return result[0][0] as int;
    } catch (e) {
      print('İş oluşturma hatası: $e');
      throw Exception('İş oluşturulamadı');
    }
  }

static Future<bool> toggleJobLock({
    required int jobId,
    required bool isLocked,
    String? password,
  }) async {
    try {
      await ensureConnection();
      await _connection!.query(
        'UPDATE jobs SET is_locked = @isLocked, lock_password = @password WHERE job_id = @jobId',
        substitutionValues: {
          'isLocked': isLocked,
          'password': password,
          'jobId': jobId,
        },
      );
      return true;
    } catch (e) {
      print('Kilit durumu güncellenirken hata: $e');
      return false;
    }
  }
  /// İşin kilit durumunu ve şifresini getirir
// DatabaseHelper sınıfına ekle
static Future<Map<String, dynamic>?> getJobLockStatus(int jobId) async {
    try {
      await ensureConnection();
      final response = await _connection!.query(
        'SELECT is_locked, lock_password FROM jobs WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      if (response.isNotEmpty) {
        return {
          'is_locked': response.first[0] as bool,
          'lock_password': response.first[1] as String?,
        };
      }
      return null;
    } catch (e) {
      print('Kilit durumu alınırken hata: $e');
      return null;
    }
  }

  /// İşin şifresini doğrular
static Future<bool> verifyJobPassword({
    required int jobId,
    required String password,
  }) async {
    try {
      await ensureConnection();
      final response = await _connection!.query(
        'SELECT lock_password FROM jobs WHERE job_id = @jobId AND is_locked = true',
        substitutionValues: {'jobId': jobId},
      );
      if (response.isNotEmpty) {
        final storedPassword = response.first[0] as String?;
        return storedPassword == password;
      }
      return false;
    } catch (e) {
      print('Şifre doğrulanırken hata: $e');
      return false;
    }
  }
    /// Katılan kullanıcının giriş zamanını kaydeder
  static Future<void> recordAttendedUserTime(int jobId, int userId, String entryTime) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO public.attended_users_log (job_id, user_id, entry_time)
        VALUES (@jobId, @userId, @entryTime)
        ON CONFLICT DO NOTHING
        ''',
        substitutionValues: {
          'jobId': jobId,
          'userId': userId,
          'entryTime': entryTime,
        },
      );
      print('Giriş zamanı başarıyla kaydedildi: Job ID: $jobId, User ID: $userId');
    } catch (e) {
      print('Giriş zamanı kaydedilirken hata: $e');
      rethrow;
    }
  }

  /// Belirli bir iş için katılan kullanıcıların giriş/çıkış loglarını getirir
  static Future<List<Map<String, dynamic>>> getAttendedUsersLog(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT log_id, job_id, user_id, entry_time, exit_time
        FROM public.attended_users_log
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => {
            'log_id': row[0],
            'job_id': row[1],
            'user_id': row[2],
            'entry_time': row[3],
            'exit_time': row[4],
          }).toList();
    } catch (e) {
      print('Katılan kullanıcıların logları alınırken hata: $e');
      return [];
    }
  }
  
  static Future<List<int>> getAssignedUsers(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT assigned_users 
        FROM public.jobs 
        WHERE job_id = @jobId
        ''',
        substitutionValues: {
          'jobId': jobId,
        },
      );
      if (result.isNotEmpty && result[0][0] != null) {
        return (result[0][0] as List<dynamic>).cast<int>();
      }
      return [];
    } catch (e) {
      print('assigned_users çekme hatası: $e');
      return [];
    }
  }
  
  static Future<bool> addAttendedUser(int jobId, int userId) async {
  await ensureConnection();
  try {
    // Mevcut listeyi al
    final currentList = await getAttendedUsers(jobId);
    
    // Kullanıcı zaten listede varsa işlem yapma
    if (currentList.contains(userId)) {
      return true;
    }
    
    // Yeni listeyi oluştur
    final updatedList = [...currentList, userId];
    
    // Veritabanını güncelle
    await _connection!.query(
      '''
      UPDATE public.jobs 
      SET attended_users = @updatedList 
      WHERE job_id = @jobId
      ''',
      substitutionValues: {
        'jobId': jobId,
        'updatedList': updatedList,
      },
    );
    
    return true;
  } catch (e) {
    print('Attended user ekleme hatası: $e');
    return false;
  }
}



  /// Görev girişi kaydeder
  static Future<void> saveTaskEntry(int jobId, int count, String type) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO public.task_entries (job_id, count, type)
        VALUES (@jobId, @count, @type)
        ''',
        substitutionValues: {'jobId': jobId, 'count': count, 'type': type},
      );
      print('Görevli giriş kaydı başarıyla eklendi.');
    } catch (e) {
      print('Görevli giriş kaydı eklenirken hata: $e');
      rethrow;
    }
  }

  /// Ek görevli giriş kaydeder
  static Future<void> saveExtraTaskEntry(int jobId, String tcKimlikNo, String teamName, String phone, String bloodGroup) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO public.extra_task_entries (job_id, tc_kimlik_no, team_name, phone, blood_group)
        VALUES (@jobId, @tcKimlikNo, @teamName, @phone, @bloodGroup)
        ''',
        substitutionValues: {
          'jobId': jobId,
          'tcKimlikNo': tcKimlikNo,
          'teamName': teamName,
          'phone': phone,
          'bloodGroup': bloodGroup,
        },
      );
      print('Ek görevli giriş kaydı başarıyla eklendi.');
    } catch (e) {
      print('Ek görevli giriş kaydı eklenirken hata: $e');
      rethrow;
    }
  }

  /// İşin başlangıç zamanını günceller
  static Future<bool> updateJobStartTime(int jobId, DateTime startTime) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        UPDATE jobs
        SET start_time = @startTime
        WHERE job_id = @jobId
        RETURNING job_id
        ''',
        substitutionValues: {'jobId': jobId, 'startTime': startTime},
      );
      if (result.isNotEmpty) {
        print('İş start_time başarıyla güncellendi. Job ID: $jobId');
        return true;
      }
      print('İş start_time güncellenirken bir hata oluştu: Sonuç döndürülmedi.');
      return false;
    } catch (e) {
      print('İş start_time güncelleme hatası: $e');
      return false;
    }
  }

  /// Tamamlanmamış işleri getirir
static Future<List<Map<String, dynamic>>> getIncompleteJobs() async {
    try {
      await ensureConnection();
      final response = await _connection!.query(
        'SELECT job_id, job_name, description, created_by, created_at, start_time, end_time, is_locked, lock_password '
        'FROM jobs WHERE end_time IS NULL ORDER BY created_at DESC',
      );
      return response.map((row) => {
        'job_id': row[0],
        'job_name': row[1],
        'description': row[2],
        'created_by': row[3],
        'created_at': row[4],
        'start_time': row[5],
        'end_time': row[6],
        'is_locked': row[7],
        'lock_password': row[8],
      }).toList();
    } catch (e) {
      print('İşler yüklenirken hata: $e');
      return [];
    }
  }
  /// Giriş yapan kullanıcının ID'sini saklar
  static Future<void> loginAndSetUserId(String username, String password) async {
    final userData = await loginUser(username, password);
    if (userData != null) {
      loggedInUserId = userData['user_id'];
      print('Giriş yapan kullanıcı ID: $loggedInUserId');
    } else {
      print('Giriş başarısız.');
    }
  }

  /// Yeni bir iş ekler
  static Future<int?> addJob({
    required String jobName,
    required String description,
    required int createdBy,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        INSERT INTO jobs (job_name, description, created_by, start_time, end_time)
        VALUES (@jobName, @description, @createdBy, @startTime, @endTime)
        RETURNING job_id
        ''',
        substitutionValues: {
          'jobName': jobName,
          'description': description,
          'createdBy': createdBy,
          'startTime': startTime ?? DateTime.now(),
          'endTime': endTime,
        },
      );
      if (result.isNotEmpty) {
        final jobId = result[0][0] as int;
        print('İş başarıyla eklendi. Job ID: $jobId');
        return jobId;
      }
      print('İş eklenirken bir hata oluştu: Sonuç döndürülmedi.');
      return null;
    } catch (e) {
      print('İş ekleme hatası: $e');
      return null;
    }
  }

  /// Kullanıcının belirli bir iş alanı içinde olup olmadığını kontrol eder
  static Future<bool> isUserInJobArea(int userId, int jobId) async {
    await ensureConnection();
    try {
      final userLocation = await _connection!.query(
        '''
        SELECT latitude, longitude
        FROM public.user_locations
        WHERE user_id = @userId
        ORDER BY recorded_at DESC
        LIMIT 1
        ''',
        substitutionValues: {'userId': userId},
      );
      if (userLocation.isEmpty) return false;

      final userLat = userLocation[0][0];
      final userLon = userLocation[0][1];

      final jobArea = await _connection!.query(
        '''
        SELECT latitude, longitude
        FROM public.job_areas
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId},
      );
      if (jobArea.isEmpty) return false;

      double minLat = jobArea[0][0];
      double maxLat = jobArea[0][0];
      double minLon = jobArea[0][1];
      double maxLon = jobArea[0][1];
      for (var point in jobArea) {
        if (point[0] < minLat) minLat = point[0];
        if (point[0] > maxLat) maxLat = point[0];
        if (point[1] < minLon) minLon = point[1];
        if (point[1] > maxLon) maxLon = point[1];
      }
      return userLat >= minLat && userLat <= maxLat && userLon >= minLon && userLon <= maxLon;
    } catch (e) {
      print('Kullanıcı konumu kontrol edilirken hata oluştu: $e');
      return false;
    }
  }

  /// Tüm işleri getirir
  static Future<List<Map<String, dynamic>>> getJobs() async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT job_id, job_name, description, created_by, created_at, start_time, end_time FROM jobs',
      );
      return result.map((row) {
        return {
          'job_id': row[0],
          'job_name': row[1],
          'description': row[2],
          'created_by': row[3],
          'created_at': row[4],
          'start_time': row[5],
          'end_time': row[6],
        };
      }).toList();
    } catch (e) {
      print('İşleri getirme hatası: $e');
      return [];
    }
  }

  /// Belirli bir işi job_id ile getirir
  static Future<Map<String, dynamic>?> getJobById(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT job_id, job_name, description, created_by, created_at, start_time, end_time FROM jobs WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      if (result.isNotEmpty) {
        return {
          'job_id': result[0][0],
          'job_name': result[0][1],
          'description': result[0][2],
          'created_by': result[0][3],
          'created_at': result[0][4],
          'start_time': result[0][5],
          'end_time': result[0][6],
        };
      }
      print('İş bulunamadı.');
      return null;
    } catch (e) {
      print('İş getirme hatası: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getTaskEntries(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT count, type, created_at
        FROM public.task_entries
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => {
            'count': row[0],
            'type': row[1],
            'created_at': row[2],
          }).toList();
    } catch (e) {
      print('Task entries alınırken hata: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getExtraTaskEntries(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT tc_kimlik_no, team_name, phone, blood_group, created_at
        FROM public.extra_task_entries
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => {
            'tc_kimlik_no': row[0],
            'team_name': row[1],
            'phone': row[2],
            'blood_group': row[3],
            'created_at': row[4],
          }).toList();
    } catch (e) {
      print('Extra task entries alınırken hata: $e');
      return [];
    }
  }
  static Future<List<Map<String, dynamic>>> getUsersNotInJob(int jobId) async {
  await ensureConnection();
  try {
    final result = await _connection!.query(
      '''
      SELECT u.user_id, u.full_name, u.group_id
      FROM public.users u
      WHERE u.user_id NOT IN (
        SELECT unnest(j.assigned_users) 
        FROM public.jobs j 
        WHERE j.job_id = @jobId
      )
      ''',
      substitutionValues: {'jobId': jobId},
    );
    return result.map((row) => {
      'user_id': row[0] as int,
      'full_name': row[1] as String,
      'group_id': row[2] as int?,
    }).toList();
  } catch (e) {
    print('İşe atanmamış kullanıcılar getirilirken hata: $e');
    return [];
  }
}

static Future<List<Map<String, dynamic>>> getGroupUsersNotInJob(int groupId, int jobId) async {
  await ensureConnection();
  try {
    final result = await _connection!.query(
      '''
      SELECT u.user_id, u.full_name
      FROM public.users u
      WHERE u.group_id = @groupId
      AND u.user_id NOT IN (
        SELECT unnest(j.assigned_users) 
        FROM public.jobs j 
        WHERE j.job_id = @jobId
      )
      ''',
      substitutionValues: {'groupId': groupId, 'jobId': jobId},
    );
    return result.map((row) => {
      'user_id': row[0] as int,
      'full_name': row[1] as String,
    }).toList();
  } catch (e) {
    print('Grubun işe atanmamış kullanıcıları getirilirken hata: $e');
    return [];
  }
}

  static Future<Map<String, dynamic>> getUserById(int userId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT full_name, title, role, kan_grubu, email, gsm_tel FROM public.users WHERE user_id = @userId',
        substitutionValues: {'userId': userId},
      );
      if (result.isNotEmpty) {
        return result.first.toColumnMap();
      }
      throw Exception('Kullanıcı bulunamadı');
    } catch (e) {
      print('Kullanıcı getirme hatası: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getUsersByGroup(int groupId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT user_id, username, password_hash, group_id, created_at, "role", full_name, title, tc_kimlik_no, gsm_tel, kan_grubu
        FROM public.users
        WHERE group_id = @groupId
        ''',
        substitutionValues: {'groupId': groupId},
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Gruba ait kullanıcıları getirme hatası: $e');
      return [];
    }
  }

  static Future<bool> assignGroupToJob(int jobId, int groupId) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO job_groups (job_id, group_id)
        VALUES (@jobId, @groupId)
        ON CONFLICT (job_id, group_id) DO NOTHING
        ''',
        substitutionValues: {'jobId': jobId, 'groupId': groupId},
      );
      print('Grup başarıyla işe atandı: Job ID: $jobId, Group ID: $groupId');
      return true;
    } catch (e) {
      print('Grup atama hatası: $e');
      return false;
    }
  }

  static Future<bool> assignUserToJob(int jobId, int userId) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        INSERT INTO job_users (job_id, user_id)
        VALUES (@jobId, @userId)
        ON CONFLICT (job_id, user_id) DO NOTHING
        ''',
        substitutionValues: {'jobId': jobId, 'userId': userId},
      );
      print('Kullanıcı başarıyla işe atandı: Job ID: $jobId, User ID: $userId');
      return true;
    } catch (e) {
      print('Kullanıcı atama hatası: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getGroups() async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT group_id, group_name, created_at FROM public."groups"',
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Grupları getirme hatası: $e');
      return [];
    }
  }

  static Future<List<int>> getAssignedGroupsByJobId(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT group_id FROM job_groups WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => row[0] as int).toList();
    } catch (e) {
      print('Atanmış grupları getirme hatası: $e');
      return [];
    }
  }

  static Future<List<int>> getAssignedUsersByJobId(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT user_id FROM job_users WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => row[0] as int).toList();
    } catch (e) {
      print('Atanmış kullanıcıları getirme hatası: $e');
      return [];
    }
  }

  static Future<int?> getCurrentUserId() async {
    await ensureConnection();
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('userId');
    } catch (e) {
      print('Mevcut kullanıcı ID alınırken hata: $e');
      return null;
    }
  }

  static Future<void> updateUserLocation(int userId, double latitude, double longitude) async {
    await ensureConnection();
    try {
      await _connection!.execute(
        '''
        INSERT INTO public.user_locations (user_id, latitude, longitude, updated_at)
        VALUES (@userId, @latitude, @longitude, NOW())
        ON CONFLICT (user_id) 
        DO UPDATE SET latitude = @latitude, longitude = @longitude, updated_at = NOW();
        ''',
        substitutionValues: {'userId': userId, 'latitude': latitude, 'longitude': longitude},
      );
      print('Kullanıcı konumu güncellendi: $userId');
    } catch (e) {
      print('Konum güncellenirken hata: $e');
      rethrow;
    }
  }

  static Future<bool> updateJobAssignments({
    required int jobId,
    required List<int> assignedGroups,
    required List<int> assignedUsers,
  }) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        UPDATE jobs
        SET assigned_groups = @assignedGroups, assigned_users = @assignedUsers
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId, 'assignedGroups': assignedGroups, 'assignedUsers': assignedUsers},
      );
      print('İş atamaları başarıyla güncellendi.');
      return true;
    } catch (e) {
      print('İş atamaları güncelleme hatası: $e');
      return false;
    }
  }
  

  static Future<List<Map<String, dynamic>>> getUserNamesByIds(List<int> userIds) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT user_id, full_name
        FROM users
        WHERE user_id = ANY(@userIds)
        ''',
        substitutionValues: {'userIds': userIds},
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Kullanıcı isimleri getirilirken bir hata oluştu: $e');
      return [];
    }
  }

  static Future<List<int>> getAttendedUsers(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        'SELECT attended_users FROM jobs WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      if (result.isNotEmpty && result[0][0] != null) {
        return List<int>.from(result[0][0] as List<dynamic>);
      }
      return [];
    } catch (e) {
      print('Katılan kullanıcılar getirilirken bir hata oluştu: $e');
      return [];
    }
  }

  static Future<void> updateAttendedUsers(int jobId, List<int> attendedUsers) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        UPDATE jobs
        SET attended_users = @attendedUsers
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId, 'attendedUsers': attendedUsers},
      );
      print('Katılan kullanıcılar başarıyla güncellendi.');
    } catch (e) {
      print('Katılan kullanıcılar güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  static Future<List<String>> getGroupNamesFromAssignedGroups(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT g.group_name
        FROM public."groups" g
        WHERE g.group_id = ANY(SELECT unnest(j.assigned_groups) FROM public.jobs j WHERE j.job_id = @jobId)
        ''',
        substitutionValues: {'jobId': jobId},
      );
      return result.map((row) => row[0] as String).toList();
    } catch (e) {
      print('Grup isimleri getirilirken bir hata oluştu: $e');
      return [];
    }
  }



  static Future<void> updateAssignedUsers(int jobId, Map<String, bool> userSelections) async {
    await ensureConnection();
    try {
      for (var entry in userSelections.entries) {
        final userId = int.parse(entry.key);
        if (entry.value) {
          await _connection!.query(
            '''
            UPDATE public.jobs
            SET assigned_users = array_append(assigned_users, @userId)
            WHERE job_id = @jobId AND NOT @userId = ANY(assigned_users)
            ''',
            substitutionValues: {'userId': userId, 'jobId': jobId},
          );
        } else {
          await _connection!.query(
            '''
            UPDATE public.jobs
            SET assigned_users = array_remove(assigned_users, @userId)
            WHERE job_id = @jobId
            ''',
            substitutionValues: {'userId': userId, 'jobId': jobId},
          );
        }
      }
      bool allAssigned = userSelections.values.every((isAssigned) => isAssigned);
      await _connection!.query(
        '''
        UPDATE public.jobs
        SET is_assignment_completed = @isCompleted
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'isCompleted': allAssigned, 'jobId': jobId},
      );
      print('Atama durumu güncellendi.');
    } catch (e) {
      print('Atama durumu güncellenirken hata oluştu: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    await ensureConnection();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('role');
      loggedInUserId ;
      await closeConnection();
      print('Oturum başarıyla kapatıldı.');
    } catch (e) {
      print('Oturum kapatma hatası: $e');
    }
  }

  static Future<void> updateAssignmentStatus(int jobId, bool isCompleted) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        UPDATE public.jobs
        SET is_assignment_completed = @isCompleted
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId, 'isCompleted': isCompleted},
      );
      print('Atama durumu güncellendi.');
    } catch (e) {
      print('Atama durumu güncellenirken hata oluştu: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getGroupNamesByIds(List<int> groupIds) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT group_id, group_name
        FROM public."groups"
        WHERE group_id = ANY(@groupIds)
        ''',
        substitutionValues: {'groupIds': groupIds},
      );
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Grup isimleri getirilirken bir hata oluştu: $e');
      return [];
    }
  }

  static Future<bool> updateJobEndTime(int jobId, DateTime endTime) async {
    await ensureConnection();
    try {
      await _connection!.query(
        'UPDATE jobs SET end_time = @endTime WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId, 'endTime': endTime},
      );
      print('İş bitiş zamanı güncellendi.');
      return true;
    } catch (e) {
      print('İş güncelleme hatası: $e');
      return false;
    }
  }

  static Future<bool> deleteJob(int jobId) async {
    await ensureConnection();
    try {
      await _connection!.query(
        'DELETE FROM jobs WHERE job_id = @jobId',
        substitutionValues: {'jobId': jobId},
      );
      print('İş başarıyla silindi.');
      return true;
    } catch (e) {
      print('İş silme hatası: $e');
      return false;
    }
  }

  static Future<void> updateJobArea({required int jobId, required double latitude, required double longitude}) async {
    await ensureConnection();
    try {
      await _connection!.query(
        '''
        UPDATE jobs
        SET area_latitude = @latitude, area_longitude = @longitude
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId, 'latitude': latitude, 'longitude': longitude},
      );
      print('Alan başarıyla güncellendi.');
    } catch (e) {
      print('Alan güncellenirken hata oluştu: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getJobArea(int jobId) async {
    await ensureConnection();
    try {
      final result = await _connection!.query(
        '''
        SELECT area_latitude, area_longitude
        FROM jobs
        WHERE job_id = @jobId
        ''',
        substitutionValues: {'jobId': jobId},
      );
      if (result.isNotEmpty) {
        return {'latitude': result[0][0] as double, 'longitude': result[0][1] as double};
      }
      return null;
    } catch (e) {
      print('Alan bilgisi alınırken hata oluştu: $e');
      return null;
    }
  }
}
