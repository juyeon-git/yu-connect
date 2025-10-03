import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'events_editor.dart';
import 'events_detail.dart';

class EventsList extends StatefulWidget {
  const EventsList({super.key});
  @override
  State<EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<EventsList> {
  static const int pageSize = 10;
  final _items = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _end = false;
  String _statusFilter = 'all'; // all | active | inactive
  String? _error;

  Query<Map<String, dynamic>> _baseQuery() {
    final col = FirebaseFirestore.instance.collection('events');
    if (_statusFilter == 'all') {
      return col.orderBy('createdAt', descending: true);
    } else {
      return col
          .where('status', isEqualTo: _statusFilter)
          .orderBy('createdAt', descending: true);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _last = null;
      _end = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = _baseQuery().limit(pageSize);
      if (_last != null) q = q.startAfterDocument(_last!);
      final snap = await q.get();
      if (snap.docs.isEmpty) {
        _end = true;
      } else {
        _last = snap.docs.last;
        _items.addAll(snap.docs);
        if (snap.docs.length < pageSize) _end = true;
      }
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  /// 타일 하나를 실시간으로 그리는 위젯
  Widget _eventTile(String docId) {
  final docRef = FirebaseFirestore.instance.collection('events').doc(docId);
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: docRef.snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const ListTile(
          title: Text('로딩 중...'),
          subtitle: Text('데이터 동기화 중'),
        );
      }
      if (!snap.data!.exists) {
        return const ListTile(
          title: Text('삭제됨'),
          subtitle: Text('문서가 삭제되었습니다.'),
        );
      }

      final doc = snap.data!;
      final data = doc.data()!;

      final title = data['title'] ?? '제목 없음';
      final status = data['status'] ?? 'unknown';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final deadline = (data['deadline'] as Timestamp?)?.toDate();
      final createdAtStr = createdAt?.toString() ?? '-';
      final deadlineStr = deadline?.toString().split(' ').first ?? '';

      // 🔧 신청자 수 계산 로직 (배열 우선, 보정은 max)
      final dynamic pField = data['participants'];
      final int arrLen = (pField is List) ? pField.length : -1;
      final int cntField = (data['participantsCount'] is int)
          ? data['participantsCount'] as int
          : -1;

      int? count;
      if (arrLen >= 0) {
        count = (cntField >= 0) ? (arrLen > cntField ? arrLen : cntField) : arrLen;
      } else if (cntField >= 0) {
        count = cntField;
      }

      Widget countWidget;
      if (count != null) {
        countWidget = Text('신청자: $count명');
      } else {
        // 최후 폴백: 서브컬렉션 집계 (규칙에서 읽기 허용 필요)
        final sub = docRef.collection('participants');
        countWidget = FutureBuilder<AggregateQuerySnapshot>(
          future: sub.count().get(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (s.hasError) return const Text('신청자: -');
            return Text('신청자: ${s.data?.count ?? 0}명');
          },
        );
      }

      return ListTile(
        title: Text(title),
        subtitle: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('상태: $status • 생성일: $createdAtStr'),
            countWidget,
            if (deadline != null) Text('• 마감일: $deadlineStr'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EventsEditor(doc: doc)),
            );
            // 편집 돌아오면 목록 리로드
            await _reload();
          },
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetail(docId: doc.id, data: data),
            ),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 헤더(기존 AppBar 기능 대체)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              const Spacer(),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'active', child: Text('진행중')),
                  DropdownMenuItem(value: 'inactive', child: Text('종료됨')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _statusFilter = v);
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '행사 등록',
                icon: const Icon(Icons.add),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EventsEditor()),
                  );
                  _reload();
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: _error != null
              ? Center(child: Text('에러: $_error'))
              : ListView.builder(
                  itemCount: _items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      if (_end) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('더 이상 데이터 없음'),
                          ),
                        );
                      }
                      _loadMore();
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // 페이징으로 불러온 문서 id만 사용하고,
                    // 실제 내용은 실시간 스트림으로 그린다.
                    final pagedDoc = _items[index];
                    return _eventTile(pagedDoc.id);
                  },
                ),
        ),
      ],
    );
  }
}
