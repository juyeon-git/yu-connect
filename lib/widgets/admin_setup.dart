import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/admin_functions.dart';

class AdminSetupPage extends StatefulWidget {
  const AdminSetupPage({super.key});
  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage> {
  bool _loading = false;
  String? _msg;

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _msg = null; });
    try {
      await AdminFunctions.bootstrapSuperAdmin();
      // 토큰 새로고침(중요)
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      setState(() { _msg = '슈퍼관리자 지정이 완료되었습니다.'; });
    } catch (e) {
      setState(() { _msg = '실패: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 초기 설정')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('최초 1회, 현재 로그인한 계정을 슈퍼관리자로 지정합니다.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _bootstrap,
                  child: _loading ? const CircularProgressIndicator() : const Text('슈퍼관리자 지정 실행'),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(_msg!, style: TextStyle(color: _msg!.startsWith('실패') ? Colors.red : Colors.green)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
