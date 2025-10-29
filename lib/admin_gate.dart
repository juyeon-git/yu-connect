import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 본문 화면 위젯들
import 'widgets/complaints_list.dart';           // 전체 민원
import 'widgets/complaints_by_category.dart';    // 카테고리별 민원
import 'widgets/events_list.dart';               // 행사 관리
import 'widgets/password_change.dart';           // 비밀번호 변경
import 'widgets/admin_approval.dart';            // 관리자 승인/권한

// ───────────────────────────────────────────
// 패널(네모칸) 공통 스타일: 연한 회색 배경 + 테두리
// ───────────────────────────────────────────
const Color kPanelBg = Color(0xFFF4F6F8); // 연한 회색
const Color kStroke  = Color(0xFFE6EAF2); // 테두리

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

    // 1) admins/{uid} 확인
    final adminDoc =
        await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    String role = (adminDoc.data()?['role'] ?? '').toString();

    // 2) users/{uid}에서 보조 정보(name/email/role) 취득
    String name = '';
    String email = user.email ?? '';
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final d = userDoc.data()!;
      name = (d['name'] ?? '').toString();
      email = (d['email'] ?? email).toString();
      if (role.isEmpty && (d['role'] ?? '') == 'admin') {
        role = 'admin';
      }
    }

    if (role == 'pending') {
      return _GateResult(user, role: 'pending', name: name, email: email);
    } else if (role == 'admin') {
      return _GateResult(user, role: 'admin', name: name, email: email);
    } else if (role == 'superAdmin') {
      return _GateResult(user, role: 'superAdmin', name: name, email: email);
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

        // 승인 대기 상태
        if (result.role == 'pending') {
          return PendingApprovalPage(onGoToLogin: _signOut);
        }

        // 일반 관리자 / 총관리자
        final isSuper = result.role == 'superAdmin';
        return AdminHomePage(
          onSignOut: _signOut,
          isSuperAdmin: isSuper,
          adminName: result.name.isNotEmpty ? result.name : '관리자',
          adminEmail: result.email,
          yuLogoAsset: null, // 에셋 있으면 'assets/yu_logo.png'
        );
      },
    );
  }
}

class _GateResult {
  final User? user;
  final String role;
  final String name;
  final String email;

  bool get signedIn => user != null;

  const _GateResult(this.user,
      {required this.role, this.name = '', this.email = ''});

  const _GateResult.notSignedIn()
      : user = null,
        role = '',
        name = '',
        email = '';
}

/// ─────────────────────────────────────────────────────────────────
/// 로그인 이후 “좌측 고정 사이드바 + 우측 본문”
/// ─────────────────────────────────────────────────────────────────

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({
    super.key,
    required this.onSignOut,
    required this.isSuperAdmin,
    required this.adminName,
    required this.adminEmail,
    this.yuLogoAsset,
  });

  final Future<void> Function() onSignOut;
  final bool isSuperAdmin;
  final String adminName;
  final String adminEmail;
  final String? yuLogoAsset;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

// ✅ 전체 민원 보기 탭 포함
enum _AdminTab {
  allComplaints,            // 전체 민원 보기
  complaintsByCategory,     // 카테고리별 민원 보기
  events,                   // 행사 관리
  changePassword,           // 비밀번호 변경
  adminRoles,               // 관리자 승인/권한 관리
}

class _AdminHomePageState extends State<AdminHomePage> {
  // 기본: 전체 민원 보기
  _AdminTab _tab = _AdminTab.allComplaints;

  static const Color _yuBlue = Color(0xFF3B73D1);
  static const Color _yuBlueDark = Color(0xFF244E8E);
  static const Color _sideBg = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    // 🔧 머티리얼3 틴트 제거 + 화면 전체 흰색 고정(상단 분홍 제거 핵심)
    final base = Theme.of(context);
    final fixedTheme = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: base.colorScheme.copyWith(surface: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
      ),
    );

    return Theme(
      data: fixedTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            // 좌측: 고정 사이드바
            Container(
              width: 220,
              color: _sideBg,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // 상단 로고/문구 (에셋 없거나 실패해도 안전)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        if (widget.yuLogoAsset?.isNotEmpty == true)
                          Image.asset(
                            widget.yuLogoAsset!,
                            height: 28,
                            errorBuilder: (context, error, stackTrace) =>
                                const _YuWordmarkFallback(),
                          )
                        else
                          const _YuWordmarkFallback(),
                        const SizedBox(width: 8),
                        Text(
                          'connect your campus',
                          style: TextStyle(
                            color: _yuBlueDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ 전체 민원 보기
                  _NavItem(
                    icon: Icons.list_alt_outlined,
                    label: '전체 민원 보기',
                    selected: _tab == _AdminTab.allComplaints,
                    onTap: () => setState(() => _tab = _AdminTab.allComplaints),
                  ),

                  // 카테고리별 민원 보기
                  _NavItem(
                    icon: Icons.grid_view_outlined,
                    label: '카테고리별 민원 보기',
                    selected: _tab == _AdminTab.complaintsByCategory,
                    onTap: () =>
                        setState(() => _tab = _AdminTab.complaintsByCategory),
                  ),

                  // 행사 관리
                  _NavItem(
                    icon: Icons.event_outlined,
                    label: '행사 관리',
                    selected: _tab == _AdminTab.events,
                    onTap: () => setState(() => _tab = _AdminTab.events),
                  ),

                  // 비밀번호 변경
                  _NavItem(
                    icon: Icons.lock_reset_outlined,
                    label: '비밀번호 변경',
                    selected: _tab == _AdminTab.changePassword,
                    onTap: () => setState(() => _tab = _AdminTab.changePassword),
                  ),

                  // 관리자 승인/권한 (총관리자만 보이기)
                  if (widget.isSuperAdmin)
                    _NavItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: '관리자 승인/권한 관리',
                      selected: _tab == _AdminTab.adminRoles,
                      onTap: () => setState(() => _tab = _AdminTab.adminRoles),
                    ),

                  const Spacer(),

                  // 하단 프로필 + 로그아웃
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: kStroke),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFDDE6F9),
                          child: Icon(Icons.person_outline,
                              color: _yuBlueDark, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.adminName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(widget.adminEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.logout, size: 16),
                                  label: const Text('로그아웃',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: widget.onSignOut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 우측: 상단 얇은 바 + 본문
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white, // 상단 바도 순백
                      border: Border(bottom: BorderSide(color: kStroke)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _titleOf(_tab),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _contentOf(_tab),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleOf(_AdminTab t) {
    switch (t) {
      case _AdminTab.allComplaints:
        return '전체 민원 보기';
      case _AdminTab.complaintsByCategory:
        return '카테고리별 민원 보기';
      case _AdminTab.events:
        return '행사 관리';
      case _AdminTab.changePassword:
        return '비밀번호 변경';
      case _AdminTab.adminRoles:
        return '관리자 승인/권한 관리';
    }
  }

  Widget _contentOf(_AdminTab t) {
    switch (t) {
      // ✅ 전체 민원: 폭이 넓을 수 있어 가로 스크롤 카드 사용
      case _AdminTab.allComplaints:
        return const _ScrollableCard(
          child: ComplaintsList(embedInOuterPanel: true),
        );

      // 카테고리별 민원: 별도의 화면 위젯 연결
      case _AdminTab.complaintsByCategory:
        return const _PlainCard(child: ComplaintsByCategoryPage(embedInOuterPanel: true));

      // 행사 관리
      case _AdminTab.events:
        return const _PlainCard(child: EventsList());

      // 비밀번호 변경
      case _AdminTab.changePassword:
        return const _PlainCard(child: PasswordChangePage(embedInOuterPanel: true, showTitle: false));

      // 관리자 승인/권한 (총관리자 전용)
      case _AdminTab.adminRoles:
        if (!widget.isSuperAdmin) {
          return const Center(
            child: Text('권한이 없습니다. (총관리자 전용)',
                style: TextStyle(color: Colors.black54)),
          );
        }
        return const _PlainCard(child: AdminApprovalPage(embedInOuterPanel: true, showTitle: false));
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE9F1FF) : Colors.transparent;
    final fg = selected ? const Color(0xFF2E5DA8) : const Color(0xFF556074);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 폭이 큰 테이블(전체 민원 등)을 위한 가로 스크롤 카드
/// 폭이 큰 테이블(전체 민원 등)을 위한 가로 스크롤/중앙 정렬 카드
class _ScrollableCard extends StatelessWidget {
  final Widget child;
  const _ScrollableCard({required this.child});

  // 표가 보기 좋은 권장 폭(원하시면 1000~1200 사이로 조정)
  static const double _idealWidth = 1100;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canCenter = constraints.maxWidth >= _idealWidth;

        // 넓으면 중앙 정렬 + 고정 최대폭, 좁으면 가로 스크롤
        final inner = canCenter
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _idealWidth),
                  child: child,
                ),
              )
            : Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: _idealWidth),
                    child: child,
                  ),
                ),
              );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: kPanelBg,
            border: Border.all(color: kStroke),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: inner,
          ),
        );
      },
    );
  }
}


/// 일반 화면을 위한 심플 카드(자체 Scaffold 없는 위젯 감싸기)
class _PlainCard extends StatelessWidget {
  final Widget child;
  const _PlainCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 가로 꽉 채우기
      decoration: BoxDecoration(
        color: kPanelBg,                         // 연한 회색 배경
        border: Border.all(color: kStroke),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }
}

/// 승인 대기 안내 화면(기존 유지)
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key, required this.onGoToLogin});

  final Future<void> Function() onGoToLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 승인 대기 중'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
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

/// 로고 에셋이 없거나 로딩 실패 시 대체 워드마크
class _YuWordmarkFallback extends StatelessWidget {
  const _YuWordmarkFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'YU',
      style: TextStyle(
        color: Color(0xFF3B73D1),
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    );
  }
}
