import 'package:flutter/material.dart';

// 오른쪽 본문에 들어갈 실제 화면들 (이미 보유하신 파일 경로)
import 'complaints_list.dart';      // class ComplaintsList
import 'events_list.dart';          // class EventsList
import 'password_change.dart';      // class PasswordChangePage
import 'admin_approval.dart';       // class AdminApprovalPage

/// 총관리자 여부에 따라 '관리자 승인/권한 관리' 메뉴 노출 제어
class AdminHomePage extends StatefulWidget {
  final bool isSuperAdmin; // users/{uid}.role == 'super' 등으로 전달
  final String adminName;
  final String adminEmail;
  final String? yuLogoAsset; // 예: 'assets/yu_logo.png'

  const AdminHomePage({
    super.key,
    required this.isSuperAdmin,
    required this.adminName,
    required this.adminEmail,
    this.yuLogoAsset,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

enum _AdminTab { complaintsByCategory, events, changePassword, adminRoles }

class _AdminHomePageState extends State<AdminHomePage> {
  // 로그인 직후 기본은 "민원 목록"이 보여야 하므로 complaintsByCategory로 둡니다.
  _AdminTab _tab = _AdminTab.complaintsByCategory;

  static const Color _yuBlue = Color(0xFF3B73D1);
  static const Color _yuBlueDark = Color(0xFF244E8E);
  static const Color _sideBg = Color(0xFFF7F9FC);
  static const Color _stroke = Color(0xFFE6EAF2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // 좌측 고정 사이드바
          Container(
            width: 220,
            color: _sideBg,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // 로고 + 슬로건
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (widget.yuLogoAsset != null)
                        Image.asset(widget.yuLogoAsset!, height: 28)
                      else
                        Text('YU',
                            style: TextStyle(
                              color: _yuBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            )),
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
                _NavItem(
                  icon: Icons.forum_outlined,
                  label: '카테고리별 민원 보기',
                  selected: _tab == _AdminTab.complaintsByCategory,
                  onTap: () => setState(() => _tab = _AdminTab.complaintsByCategory),
                ),
                _NavItem(
                  icon: Icons.event_outlined,
                  label: '행사 관리',
                  selected: _tab == _AdminTab.events,
                  onTap: () => setState(() => _tab = _AdminTab.events),
                ),
                _NavItem(
                  icon: Icons.lock_reset_outlined,
                  label: '비밀번호 변경',
                  selected: _tab == _AdminTab.changePassword,
                  onTap: () => setState(() => _tab = _AdminTab.changePassword),
                ),
                if (widget.isSuperAdmin)
                  _NavItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: '관리자 승인/권한 관리',
                    selected: _tab == _AdminTab.adminRoles,
                    onTap: () => setState(() => _tab = _AdminTab.adminRoles),
                  ),
                const Spacer(),
                // 하단 프로필 카드
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _stroke),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFDDE6F9),
                        child: Icon(Icons.person_outline, color: _yuBlueDark, size: 18),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
                    border: Border(bottom: BorderSide(color: _stroke)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _titleOf(_tab),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
    );
  }

  String _titleOf(_AdminTab t) {
    switch (t) {
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

  /// 우측 본문: 실제 파일의 화면을 그대로 삽입
  Widget _contentOf(_AdminTab t) {
    switch (t) {
      case _AdminTab.complaintsByCategory:
        // ✅ 로그인 직후 기본으로 세 번째 스샷(민원 목록) 노출
        return const _CardFrame(child: ComplaintsList());

      case _AdminTab.events:
        // events_list.dart의 실제 목록 화면
        return const _CardFrame(child: EventsList());

      case _AdminTab.changePassword:
        // password_change.dart의 비밀번호 변경 화면
        return const _CardFrame(child: PasswordChangePage());

      case _AdminTab.adminRoles:
        if (!widget.isSuperAdmin) {
          return const _CardFrame(
            child: Center(
              child: Text('권한이 없습니다. (총관리자 전용)', style: TextStyle(color: Colors.black54)),
            ),
          );
        }
        // admin_approval.dart의 관리자 승인/권한 관리 화면
        return const _CardFrame(child: AdminApprovalPage());
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
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
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

/// 우측 콘텐츠 카드 프레임(연한 테두리 + 둥근 모서리)
class _CardFrame extends StatelessWidget {
  final Widget child;
  const _CardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFE6EAF2)),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(padding: const EdgeInsets.all(8.0), child: child),
    );
  }
}
