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

                    // Firestore 문서 데이터를 가져옵니다.
                    final doc = _items[index];
                    final data = doc.data();

                    final title = data['title'] ?? '제목 없음';
                    final status = data['status'] ?? 'unknown';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final deadline = (data['deadline'] as Timestamp?)?.toDate();
                    final createdAtStr = createdAt?.toString() ?? '-';
                    final deadlineStr = deadline?.toString().split(' ').first ?? '';

                    return Column(
                      children: [
                        _EventRow(
                          title: title,
                          desc: data['desc'] ?? '',
                          status: status,
                          createdAt: createdAtStr,
                          deadline: deadlineStr,
                          applicants: (data['participants'] as List<dynamic>?)?.length ?? 0,
                          onEdit: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => EventsEditor(doc: doc)),
                            );
                            _reload();
                          },
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventDetail(docId: doc.id, data: data),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: Colors.grey), // 구분선 추가
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.title,
    required this.desc,
    required this.status,
    required this.createdAt,
    required this.deadline,
    required this.applicants,
    this.onEdit,
    this.onTap, // onTap 매개변수 추가
  });

  final String title;
  final String desc;
  final String status;
  final String createdAt;
  final String deadline;
  final int applicants;
  final VoidCallback? onEdit;
  final VoidCallback? onTap; // onTap 콜백 추가

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54);

    return GestureDetector(
      onTap: onTap, // onTap 동작 연결
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), // 글씨 크기 조정
                  ),
                  const SizedBox(height: 4),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12), // 글씨 크기 조정
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('상태: $status', style: muted),
                      Text('생성일: $createdAt', style: muted),
                      Text('마감일: $deadline', style: muted),
                      Text('신청자: ${applicants}명', style: muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '편집',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}
