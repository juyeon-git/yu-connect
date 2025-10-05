import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;
  String? _msg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력해 주세요.';
    if (!s.contains('@') || !s.contains('.')) return '올바른 이메일을 입력해 주세요.';
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _sending = true; _msg = null; });
    try {
      final email = _emailCtrl.text.trim();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _msg = '재설정 메일을 보냈습니다. 메일함을 확인해 주세요.';
      });
    } on FirebaseAuthException catch (e) {
      String m;
      switch (e.code) {
        case 'user-not-found': m = '해당 이메일의 계정을 찾을 수 없습니다.'; break;
        case 'invalid-email': m = '이메일 형식이 올바르지 않습니다.'; break;
        default: m = e.message ?? e.code;
      }
      setState(() { _msg = '실패: $m'; });
    } catch (e) {
      setState(() { _msg = '실패: $e'; });
    } finally {
      setState(() { _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  '가입하신 이메일 주소로 비밀번호 재설정 링크를 보내드립니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('재설정 메일 보내기'),
                  ),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _msg!.startsWith('실패') ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
