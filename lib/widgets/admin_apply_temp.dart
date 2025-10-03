import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../admin_gate.dart';

class AdminApplyTempPage extends StatefulWidget {
  const AdminApplyTempPage({super.key});
  @override
  State<AdminApplyTempPage> createState() => _AdminApplyTempPageState();
}

class _AdminApplyTempPageState extends State<AdminApplyTempPage> {
  bool _loading = false;
  String? _msg;
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // 로그인 화면이 AdminGate의 미로그인 상태이므로 루트로 교체 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminGate()),
      (route) => false,
    );
  }

  Future<void> _apply() async {
    setState(() { _loading = true; _msg = null; _secondsLeft = 5; });
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) throw Exception('먼저 로그인해 주세요.');
      final now = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('admins').doc(u.uid).set({
        'uid': u.uid,
        'email': u.email,
        'name': u.displayName ?? (u.email ?? '').split('@').first,
        'role': 'pending',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _msg = '신청 되었습니다. ${_secondsLeft}초 후 로그인 화면으로 이동합니다.';
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        if (_secondsLeft <= 1) {
          t.cancel();
          _toLogin();
        } else {
          setState(() {
            _secondsLeft--;
            _msg = '신청 되었습니다. ${_secondsLeft}초 후 로그인 화면으로 이동합니다.';
          });
        }
      });
    } catch (e) {
      setState(() { _msg = '실패: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 신청(임시)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('현재 로그인: ${u?.email ?? "(로그인 필요)"}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _apply,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('현재 계정으로 신청'),
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
                if (!_msg!.startsWith('실패')) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _toLogin,
                    child: const Text('바로 로그인 화면으로 이동'),
                  ),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
