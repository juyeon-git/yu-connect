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
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        backgroundColor: Colors.white, // 상단바 색상 흰색으로 설정
        elevation: 0, // 그림자 제거
        foregroundColor: Colors.black, // 텍스트 색상 검정
      ),
      body: Container(
        color: Colors.white, // 배경 색상 흰색으로 설정
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '가입하신 이메일 주소로 비밀번호 재설정 링크를 보내드립니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center, // 이메일 입력 칸을 가운데 정렬
              child: SizedBox(
                width: 250, // 버튼보다 조금 더 긴 너비로 설정
                child: TextField(
                  controller: _emailCtrl, // 기존 컨트롤러 유지
                  decoration: const InputDecoration(
                    hintText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center, // 버튼을 가운데 정렬
              child: SizedBox(
                width: 200, // 버튼 너비를 제한
                child: ElevatedButton(
                  onPressed: _send, // 기존 동작 유지
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // 버튼 색상을 파란색으로 변경
                    foregroundColor: Colors.white, // 텍스트 색상을 흰색으로 설정
                    padding: const EdgeInsets.symmetric(vertical: 12), // 버튼 크기 조정
                  ),
                  child: const Text('재설정 메일 보내기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
