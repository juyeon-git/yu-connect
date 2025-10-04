import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintDetail extends StatefulWidget {
  const ComplaintDetail({super.key, required this.doc});

  /// QueryDocumentSnapshot을 넘겨도 되고, DocumentSnapshot을 넘겨도 됩니다.
  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<ComplaintDetail> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<ComplaintDetail> {
  late Map<String, dynamic> _data;
  late String _status; // received | inProgress | done
  final _replyCtrl = TextEditingController();
  bool _savingStatus = false;
  bool _savingReply = false;

  @override
  void initState() {
    super.initState();
    _data = widget.doc.data() ?? <String, dynamic>{};
    _status = _normalizeStatus(_data['status']);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  // ---------------- Helpers ----------------

  String _normalizeStatus(dynamic raw) {
    final s = (raw ?? '').toString();
    switch (s) {
      case 'received':
      case 'pending':
        return 'received';
      case 'processing':
      case 'inProgress':
        return 'inProgress';
      case 'done':
        return 'done';
      default:
        return 'received';
    }
  }

  String _statusLabel(String v) {
    switch (v) {
      case 'received':
        return '접수';
      case 'inProgress':
        return '처리중';
      case 'done':
        return '완료';
      default:
        return v;
    }
  }

  Color _statusColor(String v) {
    switch (v) {
      case 'received':
        return Colors.blueGrey.shade600;
      case 'inProgress':
        return Colors.orange.shade700;
      case 'done':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  /// 카테고리 뱃지: 앱이 저장한 평탄화 필드(category/zone/buildingCode/buildingName)를 그대로 사용
  Widget _categoryBadge(Map<String, dynamic> d) {
    final cat = d['category'];
    String text;
    if (cat == '시설') {
      final z = d['zone'];
      final code = d['buildingCode'];
      final name = d['buildingName'];
      if (z != null && code != null && name != null) {
        text = '$cat · $z · $code $name';
      } else {
        text = (cat ?? '-').toString();
      }
    } else {
      text = (cat ?? '-').toString(); // 학사 등
    }
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  /// 작성자 라인(작성자: 이름 학번 · 작성일: …)
  Widget _authorLine(String ownerUid, dynamic createdAtTs) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, snap) {
        String who = ownerUid; // fallback
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data()!;
          final name = (u['name'] ?? '').toString();
          final sid  = (u['studentId'] ?? '').toString();
          who = sid.isNotEmpty ? '$name ($sid)' : name;
        }
        return Row(
          children: [
            Text('작성자: $who'),
            const SizedBox(width: 12),
            Text('작성일: ${_fmtTs(createdAtTs)}'),
          ],
        );
      },
    );
  }

  // ---------------- Actions ----------------

  Future<void> _saveStatus() async {
    if (_savingStatus) return;
    setState(() => _savingStatus = true);
    try {
      await widget.doc.reference.update({
        'status': _status, // 표준값으로 저장
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 로컬 상태 갱신(재조회 없이도 반영되도록 최소 필드 보정)
      setState(() {
        _data['status'] = _status;
        _data['updatedAt'] = Timestamp.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _saveReply() async {
    if (_savingReply) return;
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;

    setState(() => _savingReply = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await widget.doc.reference.collection('replies').add({
        'message': msg,
        'senderUid': uid,
        'senderRole': 'admin', // 관리자에서 작성
        'createdAt': FieldValue.serverTimestamp(),
      });
      _replyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답변이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('답변 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReply = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final title   = (_data['title'] ?? '-').toString();
    final owner   = (_data['ownerUid'] ?? '-').toString();
    final created = _data['createdAt'];

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
              const SizedBox(height: 6),

              // 메타: 작성자/작성일/상태
              Row(
                children: [
                  Expanded(child: _authorLine(owner, created)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(_status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(_status),
                      style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              // 카테고리 뱃지
              _categoryBadge(_data),

              const Divider(height: 24),

              // 본문
              Text('내용', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              SelectableText((_data['content'] ?? '-').toString()),
              const SizedBox(height: 16),

              // 상태 변경
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'received', child: Text('접수')),
                        DropdownMenuItem(value: 'inProgress', child: Text('처리중')),
                        DropdownMenuItem(value: 'done', child: Text('완료')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                      decoration: const InputDecoration(
                        labelText: '상태',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _savingStatus ? null : _saveStatus,
                    child: _savingStatus
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('상태 저장'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),

              // 답변 목록
              Text('답변 목록', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _RepliesList(parentRef: widget.doc.reference),

              const SizedBox(height: 12),

              // 답변 입력
              TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '답변 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveReply(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _savingReply ? null : _saveReply,
                  child: _savingReply
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('답변 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({required this.parentRef});
  final DocumentReference<Map<String, dynamic>> parentRef;

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  /// 답변 작성자 표시 위젯
  /// - senderRole == 'admin'  →  '관리자'
  /// - 그 외(소유자/학생)      →  users/{uid}의 이름/학번
  Widget _whoLabel(Map<String, dynamic> d) {
    final role = (d['senderRole'] ?? '').toString();
    if (role == 'admin') {
      return const Text('관리자');
    }
    final uid = (d['senderUid'] ?? '').toString();
    if (uid.isEmpty) return const Text(''); // 정보 없음

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        String who = uid; // fallback
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data()!;
          final name = (u['name'] ?? '').toString();
          final sid  = (u['studentId'] ?? '').toString();
          who = sid.isNotEmpty ? '$name ($sid)' : name;
        }
        return Text(who);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: parentRef
          .collection('replies')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('답변을 불러오는 중 오류가 발생했습니다: ${snap.error}');
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text('등록된 답변이 없습니다.');
        }
        return Column(
          children: docs.map((r) {
            final d = r.data();
            final msg = (d['message'] ?? '').toString();
            final when = _fmtTs(d['createdAt']);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _whoLabel(d),
                      const SizedBox(width: 6),
                      Text('· $when', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
