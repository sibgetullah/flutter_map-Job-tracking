import 'package:esay/user_id.dart';
import 'package:flutter/material.dart';
import '../connect_afad.dart';
import '../maps/map_service.dart';
import '../jobpage.dart';
import '../maps/map_page.dart';
import '../login_page_afad.dart';
import 'package:latlong2/latlong.dart';
import 'job_management_utils.dart';

class JobManagementService {
  static Future<void> loadJobs(
    BuildContext context,
    void Function(VoidCallback) setState,
    List<Map<String, dynamic>> jobs,
  ) async {
    try {
      await DatabaseHelper.openConnection();
      final loadedJobs = await DatabaseHelper.getIncompleteJobs();
      setState(() {
        jobs
          ..clear()
          ..addAll(loadedJobs);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşler yüklenirken bir hata oluştu: $e')),
      );
    }
  }

  static Future<void> addJob(
    BuildContext context,
    String jobName,
    int userId,
    void Function(VoidCallback) setState,
    List<Map<String, dynamic>> jobs,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
  ) async {
    if (jobName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir iş adı girin.')),
      );
      return;
    }

    final startTime = JobManagementUtils.combineDateAndTime(selectedDate, selectedTime);

    try {
      await DatabaseHelper.openConnection();
      final jobId = await DatabaseHelper.addJob(
        jobName: jobName,
        description: "Açıklama eklenmemiş",
        createdBy: userId,
        startTime: startTime,
        endTime: null,
      );

      if (jobId != null) {
        setState(() {
          jobs.insert(0, {
            'job_id': jobId,
            'job_name': jobName,
            'description': "Açıklama eklenmemiş",
            'created_by': userId,
            'created_at': DateTime.now(),
            'start_time': startTime,
            'end_time': null,
            'is_locked': false, // Varsayılan olarak kilitli değil
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$jobName başarıyla eklendi!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İş eklenirken bir hata oluştu: jobId null döndü')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İş eklenirken bir hata oluştu: $e')),
      );
      print('Hata detayları: $e');
    }
  }

  static Future<void> completeJob(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
    int index,
    void Function(VoidCallback) setState,
  ) async {
    final jobId = jobs[index]['job_id'];
    if (jobId == null) return;

    try {
      await DatabaseHelper.openConnection();
      final success = await DatabaseHelper.updateJobEndTime(jobId, DateTime.now());

      if (success) {
        final jobName = jobs[index]['job_name'];
        setState(() => jobs.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$jobName işi tamamlandı!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitiş zamanı güncellenirken bir hata oluştu.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bitiş zamanı güncellenirken bir hata oluştu: $e')),
      );
    }
  }

  static Future<void> assignGroup(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
    int index,
    bool isAdmin,
    int userId,
    void Function(VoidCallback) setState,
  ) async {
    final jobId = jobs[index]['job_id'];

    try {
      await DatabaseHelper.openConnection();
      final groups = await DatabaseHelper.getGroups();
      final assignedGroupIds = await DatabaseHelper.getAssignedGroupsByJobId(jobId);
      final assignedUserIds = await DatabaseHelper.getAssignedUsersByJobId(jobId);

      final selectedGroups = <int, bool>{
        for (var group in groups) group['group_id']: assignedGroupIds.contains(group['group_id'])
      };
      final selectedUsers = <int, Map<int, bool>>{
        for (var group in groups) group['group_id']: {}
      };
      final allUsers = <int, List<Map<String, dynamic>>>{};

      for (var group in groups) {
        final users = await DatabaseHelper.getUsersByGroup(group['group_id']);
        selectedUsers[group['group_id']] = {
          for (var user in users) user['user_id']: assignedUserIds.contains(user['user_id'])
        };
        allUsers[group['group_id']] = users;
      }

      final allUsersList = allUsers.values.expand((users) => users).toList();

      // Kişi seçim diyalog fonksiyonu
      Future<void> showUserSelectionDialog() async {
        String searchQuery = '';
        final tempSelectedUsers = Map<int, bool>.fromEntries(
          allUsersList.map((user) => MapEntry(
                user['user_id'],
                selectedUsers.entries
                    .firstWhere((entry) => entry.value.containsKey(user['user_id']))
                    .value[user['user_id']] ?? false,
              )),
        );

        await showDialog(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredUsers = searchQuery.isEmpty
                  ? allUsersList
                  : allUsersList.where((user) {
                      final fullName = user['full_name']?.toString().toLowerCase() ?? '';
                      final username = user['username']?.toString().toLowerCase() ?? '';
                      return fullName.contains(searchQuery) || username.contains(searchQuery);
                    }).toList();

              return AlertDialog(
                title: const Text('Kişi Seç'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Kullanıcı ara...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => setDialogState(() {
                            searchQuery = value.toLowerCase();
                          }),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final groupId = allUsers.entries
                                .firstWhere((entry) => entry.value.contains(user))
                                .key;
                            final groupName = groups.firstWhere((g) => g['group_id'] == groupId)['group_name'];

                            return ListTile(
                              title: Row(
                                children: [
                                  Checkbox(
                                    value: tempSelectedUsers[user['user_id']] ?? false,
                                    onChanged: (value) => setDialogState(() {
                                      tempSelectedUsers[user['user_id']] = value ?? false;
                                    }),
                                  ),
                                  Expanded(child: Text(user['full_name'] ?? 'İsimsiz')),
                                ],
                              ),
                              subtitle: Text('${user['username'] ?? 'Kullanıcı adı yok'} - $groupName'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Seçimleri ana listede güncelle
                      for (var user in allUsersList) {
                        final userId = user['user_id'];
                        final groupId = allUsers.entries
                            .firstWhere((entry) => entry.value.contains(user))
                            .key;

                        if (selectedUsers[groupId] != null) {
                          selectedUsers[groupId]![userId] = tempSelectedUsers[userId] ?? false;

                          // Grubun seçim durumunu güncelle
                          if (selectedUsers[groupId]!.values.any((v) => v)) {
                            selectedGroups[groupId] = true;
                          } else {
                            selectedGroups[groupId] = false;
                          }
                        }
                      }
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Tamam'),
                  ),
                ],
              );
            },
          ),
        );
      }

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final scrollController = ScrollController();

            return AlertDialog(
              title: const Text('Grup Seç'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, groupIndex) {
                    final group = groups[groupIndex];
                    return ExpansionTile(
                      title: Row(
                        children: [
                          Checkbox(
                            value: selectedGroups[group['group_id']] ?? false,
                            onChanged: (value) => setDialogState(() {
                              selectedGroups[group['group_id']] = value ?? false;
                              selectedUsers[group['group_id']]?.updateAll((_, v) => value ?? false);
                            }),
                          ),
                          Expanded(child: Text(group['group_name'])),
                        ],
                      ),
                      children: [
                        Column(
                          children: allUsers[group['group_id']]!.map((user) => ListTile(
                            title: Row(
                              children: [
                                Checkbox(
                                  value: selectedUsers[group['group_id']]![user['user_id']] ?? false,
                                  onChanged: (value) => setDialogState(() {
                                    selectedUsers[group['group_id']]![user['user_id']] = value ?? false;
                                    if (value == true) {
                                      selectedGroups[group['group_id']] = true;
                                    } else if (!selectedUsers[group['group_id']]!.values.any((v) => v)) {
                                      selectedGroups[group['group_id']] = false;
                                    }
                                  }),
                                ),
                                Expanded(child: Text(user['full_name'] ?? 'İsimsiz')),
                              ],
                            ),
                            subtitle: Text(user['username'] ?? 'Kullanıcı adı yok'),
                          )).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () async {
                    await showUserSelectionDialog();
                    setDialogState(() {});
                  },
                  child: const Text('Kişi Seç'),
                ),
                TextButton(
                  onPressed: () async {
                    final selectedGroupIds =
                        selectedGroups.entries.where((e) => e.value).map((e) => e.key).toList();
                    final selectedUserIds = selectedUsers.values
                        .expand((userMap) => userMap.entries)
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();

                    await DatabaseHelper.updateJobAssignments(
                      jobId: jobId,
                      assignedGroups: selectedGroupIds,
                      assignedUsers: selectedUserIds,
                    );

                    Navigator.pop(dialogContext);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailsPage(
                          jobTitle: jobs[index]['job_name'],
                          description: jobs[index]['description'],
                          createdBy: "Kullanıcı $userId",
                          startTime: jobs[index]['start_time'],
                          endTime: jobs[index]['end_time'],
                          isAdmin: isAdmin,
                          onEdit: isAdmin ? () {} : null,
                          onDelete: isAdmin ? () {} : null,
                          jobId: jobId,
                          isLocked: jobs[index]['is_locked'] ?? false, // Zorunlu parametre eklendi
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gruplar yüklenirken bir hata oluştu: $e')),
      );
    }
  }

  static Future<void> navigateToMapPage(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
    int index,
  ) async {
    final jobId = jobs[index]['job_id'];

    final result = await Navigator.push<(List<LatLng>, bool)>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          jobId: jobId,
          onAreaSelected: (area, isScanned) => Navigator.pop(context, (area, isScanned)),
        ),
      ),
    );

    if (result == null || result.$1.isEmpty) return;

    final selectedArea = result.$1;
    final isScanned = result.$2;

    try {
      final areaNameController = TextEditingController();
      final areaName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alan İsmi Girin'),
          content: TextField(
            controller: areaNameController,
            decoration: const InputDecoration(hintText: 'Örn: Depo Alanı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, areaNameController.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );

      if (areaName == null || areaName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alan ismi boş olamaz')),
        );
        return;
      }

      final existingAreas = await MapsService.getJobAreasByJobId(jobId);
      final newAreaId = existingAreas.isEmpty
          ? 1
          : (existingAreas.keys.reduce((a, b) => a > b ? a : b) + 1);

      await MapsService.addJobArea(
        jobId: jobId,
        areaId: newAreaId,
        polygonPoints: selectedArea,
        areaName: areaName,
        isScanned: isScanned,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$areaName" alanı başarıyla kaydedildi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alan kaydedilirken bir hata oluştu: $e')),
      );
    }
  }

  static Future<void> logout(BuildContext context) async {
    try {
      await DatabaseHelper.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılırken bir hata oluştu: $e')),
      );
    }
  }

  static Future<void> updateJobStartTime(
    BuildContext context,
    int jobId,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    void Function(VoidCallback) setState,
    List<Map<String, dynamic>> jobs,
    int index,
  ) async {
    final startTime = JobManagementUtils.combineDateAndTime(selectedDate, selectedTime);

    if (startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir tarih ve saat seçin.')),
      );
      return;
    }

    try {
      await DatabaseHelper.ensureConnection();
      final success = await DatabaseHelper.updateJobStartTime(jobId, startTime);

      if (success) {
        setState(() => jobs[index]['start_time'] = startTime);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İş başlangıç zamanı başarıyla güncellendi.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başlangıç zamanı güncellenirken bir hata oluştu.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Başlangıç zamanı güncellenirken bir hata oluştu: $e')),
      );
    }
  }
}