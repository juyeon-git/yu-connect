import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ob1 = true, _ob2 = true, _ob3 = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _msg = '로그인 상태가 아닙니다.');
      return;
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      setState(() => _msg = '이메일 로그인 계정에서만 비밀번호 변경이 가능합니다.');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _msg = '새 비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _msg = '새 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setState(() { _busy = true; _msg = null; });
    try {
      // 1) 재인증
      final cred = EmailAuthProvider.credential(email: email, password: _currentCtrl.text);
      await user.reauthenticateWithCredential(cred);

      // 2) 비밀번호 변경
      await user.updatePassword(_newCtrl.text);

      if (!mounted) return;
      setState(() => _msg = '비밀번호가 변경되었습니다. 다시 로그인해 주세요.');

      // 3) 보안상 로그아웃 유도
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/signIn', (r) => false);
    } on FirebaseAuthException catch (e) {
      String m;
      switch (e.code) {
        case 'wrong-password': m = '현재 비밀번호가 올바르지 않습니다.'; break;
        case 'weak-password': m = '새 비밀번호가 너무 약합니다.'; break;
        case 'too-many-requests': m = '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.'; break;
        case 'requires-recent-login': m = '보안을 위해 다시 로그인 후 시도해 주세요.'; break;
        default: m = e.message ?? e.code;
      }
      setState(() => _msg = '실패: $m');
    } catch (e) {
      setState(() => _msg = '실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _currentCtrl,
                obscureText: _ob1,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ob1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ob1 = !_ob1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newCtrl,
                obscureText: _ob2,
                decoration: InputDecoration(
                  labelText: '새 비밀번호(6자 이상)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ob2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ob2 = !_ob2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: _ob3,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ob3 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ob3 = !_ob3),
                  ),
                ),
                onSubmitted: (_) => _change(),
              ),
              const SizedBox(height: 12),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _msg!.startsWith('실패') ? Colors.red : Colors.green),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _change,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('비밀번호 변경'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
