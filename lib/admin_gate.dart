import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/complaints_list.dart';
import 'widgets/complaints_by_category.dart';

// 기존 기능 파일들
import 'widgets/admin_apply_temp.dart';
import 'widgets/admin_approval.dart';
import 'widgets/events_list.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  Future<_GateResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = _checkAuthAndRole();
  }

  Future<_GateResult> _checkAuthAndRole() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return const _GateResult.notSignedIn();

    final uid = user.uid;

    // admins/{uid} 문서 확인
    final adminDoc =
        await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    final role = adminDoc.data()?['role'] ?? '';

    if (role == 'pending') {
      return _GateResult(user, role: 'pending');
    } else if (role == 'admin') {
      return _GateResult(user, role: 'admin');
    } else if (role == 'superAdmin') {
      return _GateResult(user, role: 'superAdmin');
    }

    // users.role == 'admin' 체크 (보조)
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
      return _GateResult(user, role: 'admin');
    }

    return const _GateResult.notSignedIn();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/signIn', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snap.data;

        // 로그인 안 된 경우 → 로그인 화면으로
        if (result == null || !result.signedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/signIn');
          });
          return const SizedBox();
        }

        // ✅ 승인 대기 상태: 안내 + 로그인 화면으로 이동 버튼
        if (result.role == 'pending') {
          return PendingApprovalPage(onGoToLogin: _signOut);
        }

        // 일반 관리자
        if (result.role == 'admin') {
          return AdminHomePage(onSignOut: _signOut, isSuperAdmin: false);
        }

        // 총관리자
        if (result.role == 'superAdmin') {
          return AdminHomePage(onSignOut: _signOut, isSuperAdmin: true);
        }

        // 기본 fallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/signIn');
        });
        return const SizedBox();
      },
    );
  }
}

class _GateResult {
  final User? user;
  final String role;
  bool get signedIn => user != null;

  const _GateResult(this.user, {required this.role});
  const _GateResult.notSignedIn() : user = null, role = '';
}

/// 관리자 홈
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({
    super.key,
    required this.onSignOut,
    required this.isSuperAdmin,
  });

  final Future<void> Function() onSignOut;
  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 홈'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isSuperAdmin ? Colors.indigo.shade50 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  isSuperAdmin ? '총관리자' : '관리자',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSuperAdmin ? Colors.indigo : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 전체 민원
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('전체 민원 보기'),
              subtitle: const Text('최신순 · 필터/검색 가능'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('전체 민원')),
                    body: const ComplaintsList(),
                  ),
                ));
              },
            ),
          ),
          const SizedBox(height: 8),

          // 카테고리별 민원
          Card(
            child: ListTile(
              leading: const Icon(Icons.grid_view_outlined),
              title: const Text('카테고리별 민원 보기'),
              subtitle: const Text('시설(A~G→건물) · 학사 / 상태별(접수·처리중·완료)'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ComplaintsByCategoryPage(),
                ));
              },
            ),
          ),
          const SizedBox(height: 8),

          // 행사 관리
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('행사 관리'),
              subtitle: const Text('행사 등록 · 수정 · 삭제'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('행사 관리')),
                    body: const EventsList(),
                  ),
                ));
              },
            ),
          ),
          const SizedBox(height: 8),

          // 비밀번호 변경 (모든 관리자 공통)
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('비밀번호 변경'),
              subtitle: const Text('현재 비밀번호 확인 후 새 비밀번호로 변경'),
              onTap: () => Navigator.pushNamed(context, '/change-password'),
            ),
          ),
          const SizedBox(height: 8),

          // 관리자 승인 (총관리자 전용)
          if (isSuperAdmin)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('관리자 승인/권한 관리'),
                subtitle: const Text('신청 관리 · 승인 · 거절'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminApprovalPage(),
                  ));
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 승인 대기 안내 화면
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key, required this.onGoToLogin});

  final Future<void> Function() onGoToLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 승인 대기 중')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '총관리자의 승인 후 이용할 수 있습니다.\n승인 완료 후 다시 로그인해 주세요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onGoToLogin,
                  child: const Text('로그인 화면으로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
