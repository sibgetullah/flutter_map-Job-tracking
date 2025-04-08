import 'package:esay/connect_afad.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'job_management_styles.dart';
import 'job_management_utils.dart';

class JobManagementWidgets {
  static AppBar buildAppBar(
    BuildContext context, // Diyalog için context gerekli
    bool isAdmin,
    VoidCallback navigateToUserInfo,
    VoidCallback logout,
    VoidCallback onAddJob, // İş ekleme callback'i
    TextEditingController jobController, // İş adı için controller
  ) {
    return AppBar(
      title: Text(
        isAdmin ? 'Yönetici Paneli' : 'İş Listesi',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.blue[900],
      actions: [
        if (isAdmin) // Sadece admin için iş ekleme
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Yeni İş Ekle'),
                  content: TextField(
                    controller: jobController,
                    decoration: InputDecoration(
                      labelText: 'İş Adı',
                      labelStyle: TextStyle(color: JobManagementStyles.darkBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: JobManagementStyles.darkBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: JobManagementStyles.lightBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (jobController.text.isNotEmpty) {
                          Navigator.pop(context);
                          onAddJob(); // İş ekleme işlemini tetikle
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('İş adı boş olamaz!')),
                          );
                        }
                      },
                      child: Text('Ekle'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'İş Ekle',
          ),
        IconButton(
          icon: Icon(Icons.person, color: Colors.white),
          onPressed: navigateToUserInfo,
        ),
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: logout,
          tooltip: 'Çıkış Yap',
        ),
      ],
    );
  }

  // buildAddJobSection kaldırıldı, çünkü AppBar'a taşındı

  static Widget buildJobGrid(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
    bool isAdmin,
    int userId,
    AnimationController animationController,
    Function(BuildContext, int) navigateToJobDetails,
    Function(int) completeJob,
    Function(int) assignGroup,
    Function(int) navigateToMapPage,
    Function(BuildContext, int, int) selectDateTime,
    Function(int) showUsersInArea,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    VoidCallback refreshCallback,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.60,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isLocked = job['is_locked'] ?? false;

        return GestureDetector(
          onTap: () => navigateToJobDetails(context, index),
          child: AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Card(
                elevation: 8.0,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        JobManagementStyles.darkBlue,
                        JobManagementStyles.mediumBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: isLocked && isAdmin
                        ? Border.all(color: Colors.yellow, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (isLocked && isAdmin)
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock,
                              color: Colors.yellow,
                              size: 18,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isLocked && isAdmin)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4.0),
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          job['job_name'],
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (job['start_time'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(job['start_time'].toString()))}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isAdmin)
                              IgnorePointer(
                                ignoring: isLocked,
                                child: Opacity(
                                  opacity: isLocked ? 0.5 : 1.0,
                                  child: Column(
                                    children: [
                                      _buildSmallButton(
                                        'Tarih Güncelle',
                                        Colors.blue,
                                        () async {
                                          await selectDateTime(context, job['job_id'], index);
                                        },
                                      ),
                                      SizedBox(height: 6),
                                      _buildSmallButton(
                                        'Grup Ekle',
                                        Colors.orange,
                                        () => assignGroup(index),
                                      ),
                                      SizedBox(height: 6),
                                      _buildSmallButton(
                                        'Haritadan Seç',
                                        const Color.fromARGB(255, 226, 156, 158),
                                        () => navigateToMapPage(index),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.white, size: 22),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onSelected: (String value) async {
                              if (value == 'complete' && !isLocked) {
                                completeJob(index);
                              } else if (value == 'users' && !isLocked) {
                                await _showDescriptionDialog(
                                  context,
                                  job['job_id'],
                                  jobs[index]['description'],
                                  refreshCallback,
                                );
                              } else if (value == 'lock') {
                                await _toggleJobLock(
                                  context,
                                  job['job_id'],
                                  isLocked,
                                  refreshCallback,
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                PopupMenuItem<String>(
                                  value: 'complete',
                                  enabled: !isLocked,
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: isLocked ? Colors.grey : Colors.green, size: 22),
                                      SizedBox(width: 10),
                                      Text('Tamamla', style: TextStyle(color: isLocked ? Colors.grey : Colors.black)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'users',
                                  enabled: !isLocked,
                                  child: Row(
                                    children: [
                                      Icon(Icons.people, color: isLocked ? Colors.grey : Colors.blue, size: 22),
                                      SizedBox(width: 10),
                                      Text('Açıklama Ekle', style: TextStyle(color: isLocked ? Colors.grey : Colors.black)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'lock',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLocked ? Icons.lock_open : Icons.lock,
                                        color: isLocked ? Colors.green : Colors.orange,
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Text(isLocked ? 'Kilidi Aç' : 'Kilitle'),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> _toggleJobLock(
    BuildContext context,
    int jobId,
    bool isLocked,
    VoidCallback refreshCallback,
  ) async {
    if (!isLocked) {
      final passwordController1 = TextEditingController();
      final passwordController2 = TextEditingController();

      final password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('İş Kilitle - Şifre Belirleme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController1,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Şifreyi girin',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController2,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Şifreyi tekrar girin',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (passwordController1.text.isEmpty || passwordController2.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Şifre alanları boş olamaz!')),
                  );
                } else if (passwordController1.text != passwordController2.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Şifreler eşleşmiyor!')),
                  );
                } else {
                  Navigator.pop(context, passwordController1.text);
                }
              },
              child: Text('Kilitle'),
            ),
          ],
        ),
      );

      if (password != null) {
        final success = await DatabaseHelper.toggleJobLock(
          jobId: jobId,
          isLocked: true,
          password: password,
        );
        if (success) {
          refreshCallback();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('İş kilitlendi!')),
          );
        }
      }
    } else {
      final password = await _showUnlockDialog(context);
      if (password != null) {
        final isValid = await DatabaseHelper.verifyJobPassword(
          jobId: jobId,
          password: password,
        );
        if (isValid) {
          final success = await DatabaseHelper.toggleJobLock(
            jobId: jobId,
            isLocked: false,
            password: null,
          );
          if (success) {
            refreshCallback();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kilit açıldı!')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hatalı şifre!')),
          );
        }
      }
    }
  }

  static Future<String?> _showUnlockDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kilidi Aç'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Şifreyi girin',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Şifre boş olamaz!')),
                );
              }
            },
            child: Text('Onayla'),
          ),
        ],
      ),
    );
  }

  static Widget _buildSmallButton(
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 100,
        minWidth: 80,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          textStyle: TextStyle(fontSize: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static Widget buildUserInfoPanel(
    BuildContext context,
    Map<String, dynamic> userInfo,
    bool isLoadingUserInfo,
    VoidCallback toggleUserInfoPanel,
  ) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kullanıcı Bilgileri',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: JobManagementStyles.darkBlue,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: JobManagementStyles.darkBlue),
                  onPressed: toggleUserInfoPanel,
                ),
              ],
            ),
            Divider(
              color: JobManagementStyles.darkBlue,
              thickness: 1,
            ),
            SizedBox(height: 10),
            Expanded(
              child: isLoadingUserInfo
                  ? Center(
                      child: CircularProgressIndicator(
                        color: JobManagementStyles.darkBlue,
                      ),
                    )
                  : ListView(
                      children: [
                        _buildInfoTile('Ad Soyad', userInfo['full_name']),
                        _buildInfoTile('Unvan', userInfo['title']),
                        _buildInfoTile('Rol', userInfo['role']),
                        _buildInfoTile('Kan Grubu', userInfo['kan_grubu']),
                        _buildInfoTile('Email', userInfo['email']),
                        _buildInfoTile('Telefon', userInfo['gsm_tel']),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInfoTile(String label, String? value) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          _getIconForLabel(label),
          color: JobManagementStyles.darkBlue,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: JobManagementStyles.darkBlue,
          ),
        ),
        subtitle: Text(
          value ?? 'Bilgi Yok',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  static Future<void> _showDescriptionDialog(
    BuildContext context,
    int jobId,
    String? currentDescription,
    VoidCallback onDescriptionUpdated,
  ) async {
    TextEditingController descriptionController =
        TextEditingController(text: currentDescription ?? '');

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Açıklama Ekle'),
          content: TextField(
            controller: descriptionController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Açıklamayı buraya girin',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Kaydet'),
              onPressed: () async {
                try {
                  await DatabaseHelper.updateJobDescription(
                      jobId, descriptionController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Açıklama başarıyla kaydedildi')),
                  );
                  onDescriptionUpdated();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Açıklama kaydedilirken hata oluştu: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  static IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Ad Soyad':
        return Icons.person;
      case 'Unvan':
        return Icons.work;
      case 'Rol':
        return Icons.security;
      case 'Kan Grubu':
        return Icons.favorite;
      case 'Email':
        return Icons.email;
      case 'Telefon':
        return Icons.phone;
      default:
        return Icons.info;
    }
  }
}