import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/admin_functions.dart';

/// 내부 패널(카드) 색상
const Color _panelBg = Color(0xFFF4F6F8); // 연한 회색
const Color _stroke  = Color(0xFFE6EAF2); // 테두리

/// 총관리자 전용: 관리자 승인/거절/삭제 페이지
/// - embedInOuterPanel=true : AdminGate의 카드 내부에 포함될 때 사용(내부 카드만 회색)
/// - showTitle=false        : 내부 카드 상단의 큰 제목을 숨김
class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({
    super.key,
    this.embedInOuterPanel = false,
    this.showTitle = false,
  });

  /// AdminGate의 카드 안에서 사용할지 여부(Scaffold 없이, 내부 패널만 회색)
  final bool embedInOuterPanel;

  /// 내부 패널 상단 제목 표시 여부
  final bool showTitle;

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  String _filter = 'pending'; // pending | admin | superAdmin
  bool _busy = false;

  // 역할별 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final col = FirebaseFirestore.instance.collection('admins');
    switch (_filter) {
      case 'admin':
        return col
            .where('role', isEqualTo: 'admin')
            .orderBy('updatedAt', descending: true)
            .limit(200)
            .snapshots();
      case 'superAdmin':
        return col
            .where('role', isEqualTo: 'superAdmin')
            .orderBy('updatedAt', descending: true)
            .limit(50)
            .snapshots();
      case 'pending':
      default:
        return col
            .where('role', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots();
    }
  }

  String _fmtTs(Timestamp? t) {
    if (t == null) return '-';
    final d = t.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _approve(String uid) async {
    setState(() => _busy = true);
    try {
      await AdminFunctions.approve(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('승인 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('승인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('거절'),
        content: const Text('이 사용자를 승인 대기 상태로 되돌릴까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await AdminFunctions.reject(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('처리 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('신청 삭제'),
        content: const Text('해당 신청 문서를 삭제할까요?\n(사용자는 나중에 다시 신청할 수 있습니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await AdminFunctions.remove(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 공통 본문(리스트) 위젯
  Widget _buildList() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('오류: ${snap.error}'));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('대기 중인 요청이 없습니다.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = docs[i].data();
                final uid = (m['uid'] ?? docs[i].id) as String;
                final name = (m['name'] ?? '') as String;
                final username = (m['username'] ?? '') as String;
                final email = (m['email'] ?? '') as String;
                final dept = (m['dept'] ?? '') as String;
                final role = (m['role'] ?? '-') as String;
                final createdAt = m['createdAt'] as Timestamp?;
                final updatedAt = m['updatedAt'] as Timestamp?;

                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(name.isEmpty ? email : '$name  <$email>'),
                  subtitle: Text([
                    if (username.isNotEmpty) '아이디: $username',
                    if (dept.isNotEmpty) '소속/직책: $dept',
                    if (role.isNotEmpty) '상태: $role',
                    '신청/갱신: ${_fmtTs(createdAt ?? updatedAt)}',
                    'uid: $uid',
                  ].join('  •  ')),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      if (role == 'pending') ...[
                        ElevatedButton(
                          onPressed: _busy ? null : () => _approve(uid),
                          child: const Text('승인'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : () => _delete(uid),
                          child: const Text('삭제'),
                        ),
                      ] else if (role == 'admin') ...[
                        OutlinedButton(
                          onPressed: _busy ? null : () => _reject(uid),
                          child: const Text('거절(대기 전환)'),
                        ),
                      ] else ...[
                        const SizedBox.shrink(),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (_busy)
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          ),
      ],
    );
  }

  /// 임베드(내부 카드만 회색) 모드 UI
  Widget _buildEmbedded() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: _panelBg, // 내부 패널만 회색
          border: Border.all(color: _stroke),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showTitle)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('관리자 승인 요청',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v!),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('대기 중')),
                    DropdownMenuItem(value: 'admin', child: Text('관리자')),
                    DropdownMenuItem(value: 'superAdmin', child: Text('총관리자')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  /// 독립 페이지(Scaffold 포함) 모드 UI
  Widget _buildStandalone() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 승인 요청'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v!),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('대기 중')),
                  DropdownMenuItem(value: 'admin', child: Text('관리자')),
                  DropdownMenuItem(value: 'superAdmin', child: Text('총관리자')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: _panelBg, // 내부 카드 회색
            border: Border.all(color: _stroke),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: _buildList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.embedInOuterPanel ? _buildEmbedded() : _buildStandalone();
  }
}
