import 'package:flutter/material.dart';
import 'package:esay/connect_afad.dart';
import 'package:postgres/postgres.dart';

class JobLockWidget extends StatefulWidget {
  final int jobId;
  final bool isInitiallyLocked;
  final Function(bool) onLockStatusChanged;

  const JobLockWidget({
    Key? key,
    required this.jobId,
    required this.isInitiallyLocked,
    required this.onLockStatusChanged,
  }) : super(key: key);

  @override
  _JobLockWidgetState createState() => _JobLockWidgetState();
}

class _JobLockWidgetState extends State<JobLockWidget> {
  late bool _isLocked;
  final TextEditingController _passwordController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.isInitiallyLocked;
  }

  Future<void> _toggleLock() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      if (_isLocked) {
        await _unlockJob();
      } else {
        await _lockJob();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _lockJob() async {
    final password = await _showSetPasswordDialog();
    if (password == null) return;

    final success = await _updateLockStatus(
      isLocked: true,
      password: password,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İş başarıyla kilitlendi')),
      );
    }
  }

  Future<void> _unlockJob() async {
    final isVerified = await _verifyPassword();
    if (!isVerified) return;

    final success = await _updateLockStatus(isLocked: false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İş kilidi başarıyla açıldı')),
      );
    }
  }
  Future<bool> _verifyPassword() async {
    PostgreSQLConnection? connection;
    try {
      // Bağlantıyı güvenli şekilde al
      connection = await DatabaseHelper.getConnection();
      if (connection == null || connection.isClosed) {
        throw Exception('Veritabanı bağlantısı kurulamadı');
      }

      final result = await connection.query(
        'SELECT lock_password FROM public.jobs WHERE job_id = @jobId',
        substitutionValues: {'jobId': widget.jobId},
      );

      if (result.isEmpty) return false;
      
      final savedPassword = result[0][0] as String?;
      if (savedPassword == null) return true;

      final enteredPassword = await showDialog<String>(
        context: context,
        builder: (context) => PasswordDialog(
          title: 'Şifre Doğrulama',
          hintText: 'Şifreyi girin',
        ),
      );

      return enteredPassword == savedPassword;
    } catch (e) {
      print('Şifre doğrulama hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doğrulama sırasında hata oluştu: ${e.toString()}')),
      );
      return false;
    } finally {
      // Bağlantıyı kapat
      if (connection != null && !connection.isClosed) {
        await connection.close();
      }
    }
  }
  
Future<String?> _showSetPasswordDialog() async {
  try {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => SetPasswordDialog(),
    );

    if (result == null || result['password']!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir şifre giriniz')),
        );
      }
      return null;
    }
    return result['password'];
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şifre belirleme hatası: ${e.toString()}')),
      );
    }
    return null;
  }
}

Future<bool> _updateLockStatus({
  required bool isLocked,
  String? password,
}) async {
  PostgreSQLConnection? connection;
  try {
    // Güvenli bağlantı alımı
    connection = await DatabaseHelper.getConnection();
    if (connection == null || connection.isClosed) {
      throw Exception('Veritabanı bağlantısı kurulamadı');
    }

    // Transaction kullanarak daha güvenli güncelleme
    await connection.transaction((ctx) async {
      await ctx.query(
        '''
        UPDATE public.jobs 
        SET is_locked = @isLocked, 
            lock_password = @password,
            updated_at = NOW()
        WHERE job_id = @jobId
        ''',
        substitutionValues: {
          'jobId': widget.jobId,
          'isLocked': isLocked,
          'password': password,
        },
      );
    });

    if (mounted) {
      setState(() => _isLocked = isLocked);
      widget.onLockStatusChanged(isLocked);
    }
    return true;
  } catch (e) {
    print('Kilit durumu güncelleme hatası: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kilit durumu güncellenemedi: ${e.toString()}')),
      );
    }
    return false;
  } finally {
    // Bağlantıyı her durumda kapat
    if (connection != null && !connection.isClosed) {
      await connection.close();
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return _isProcessing
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: _isLocked ? Colors.red : Colors.green,
            ),
            onPressed: _toggleLock,
          );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}

class PasswordDialog extends StatefulWidget {
  final String title;
  final String hintText;

  const PasswordDialog({
    required this.title,
    required this.hintText,
    Key? key,
  }) : super(key: key);

  @override
  _PasswordDialogState createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        obscureText: true,
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Onayla'),
        ),
      ],
    );
  }
}

class SetPasswordDialog extends StatefulWidget {
  @override
  _SetPasswordDialogState createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<SetPasswordDialog> {
  final TextEditingController _passwordController1 = TextEditingController();
  final TextEditingController _passwordController2 = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _passwordController1.dispose();
    _passwordController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('İşi Kilitle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController1,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Şifre belirleyin'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _passwordController2,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Şifreyi tekrar girin',
              errorText: _showError ? 'Şifreler uyuşmuyor' : null,
            ),
            onChanged: (_) => setState(() => _showError = false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal'),
        ),
        TextButton(
          onPressed: _validateAndSubmit,
          child: Text('Kaydet'),
        ),
      ],
    );
  }

  void _validateAndSubmit() {
    if (_passwordController1.text.isEmpty || 
        _passwordController1.text != _passwordController2.text) {
      setState(() => _showError = true);
      return;
    }

    Navigator.pop(context, {
      'password': _passwordController1.text,
    });
  }
}