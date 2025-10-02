import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminApplyTempPage extends StatefulWidget {
  const AdminApplyTempPage({super.key});
  @override
  State<AdminApplyTempPage> createState() => _AdminApplyTempPageState();
}

class _AdminApplyTempPageState extends State<AdminApplyTempPage> {
  bool _loading = false;
  String? _msg;

  Future<void> _apply() async {
    setState(() { _loading = true; _msg = null; });
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
      setState(() => _msg = '신청이 등록되었습니다(pending).');
    } catch (e) {
      setState(() => _msg = '실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 신청(임시)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('현재 로그인: ${u?.email ?? "(로그인 필요)"}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _apply,
              child: _loading ? const CircularProgressIndicator() : const Text('현재 계정으로 신청'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!, style: TextStyle(color: _msg!.startsWith('실패') ? Colors.red : Colors.green)),
            ]
          ]),
        ),
      ),
    );
  }
}
