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

  // 현재 페이지 문서들
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rows = [];

  // 각 페이지 마지막 문서 커서 (1페이지의 커서는 rows.last)
  final List<DocumentSnapshot<Map<String, dynamic>>> _cursors = [];

  int _page = 1;          // 현재 페이지 (1부터)
  bool _hasNext = false;  // 다음 페이지 존재 여부
  bool _loading = false;
  String? _error;

  // 필터 상태
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = 'all'; // 초기 필터 상태 설정
    _resetAndLoad(); // 최초 1페이지 로드
  }

  Query<Map<String, dynamic>> _baseQuery() {
    final col = FirebaseFirestore.instance.collection('events');
    if (_statusFilter == 'all') {
      return col.orderBy('createdAt', descending: true);
    } else {
      return col
          .where('status', isEqualTo: _statusFilter)
          .orderBy('createdAt', descending: true); // 이 조합에 대해 색인이 필요
    }
  }

  Future<void> _loadPage(int toPage) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> q = _baseQuery().limit(pageSize + 1);

      if (toPage > 1) {
        final cursorIndex = (toPage - 2);
        if (cursorIndex < 0 || cursorIndex >= _cursors.length) {
          return _resetAndLoad();
        }
        q = q.startAfterDocument(_cursors[cursorIndex]);
      }

      final snap = await q.get();
      final docs = snap.docs;

      _hasNext = docs.length > pageSize;
      final pageDocs = docs.take(pageSize).toList();

      if (_cursors.length < toPage) {
        if (pageDocs.isNotEmpty) {
          _cursors.add(pageDocs.last);
        }
      } else {
        if (pageDocs.isNotEmpty) _cursors[toPage - 1] = pageDocs.last;
      }

      setState(() {
        _page = toPage;
        _rows = pageDocs;
      });
    } catch (e) {
      setState(() => _error = '목록을 불러오는 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetAndLoad() async {
    _rows.clear();
    _cursors.clear();
    _hasNext = false;
    _page = 1;
    _error = null;
    await _loadPage(1);
  }

  Widget _buildPaginator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: (_page > 1 && !_loading) ? () => _loadPage(_page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전'),
          ),
          const SizedBox(width: 12),
          Text('$_page 페이지', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: (_hasNext && !_loading) ? () => _loadPage(_page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('다음'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 필터 및 등록 버튼
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
                  _resetAndLoad();
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
                  _resetAndLoad();
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: _error != null
              ? Center(child: Text('에러: $_error'))
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final doc = _rows[index];
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
                          doc: doc, // 추가
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
                            _resetAndLoad();
                          },
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventDetail(docId: doc.id, data: data),
                              ),
                            );
                          },
                          onDelete: _resetAndLoad, // 삭제 후 목록 갱신
                        ),
                        const Divider(height: 1, color: Colors.grey),
                      ],
                    );
                  },
                ),
        ),

        _buildPaginator(),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.doc, // 추가
    required this.title,
    required this.desc,
    required this.status,
    required this.createdAt,
    required this.deadline,
    required this.applicants,
    this.onEdit,
    this.onTap,
    this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc; // 추가
  final String title;
  final String desc;
  final String status;
  final String createdAt;
  final String deadline;
  final int applicants;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54);

    return GestureDetector(
      onTap: onTap,
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
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
          Column(
            children: [
              IconButton(
                tooltip: '편집',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('삭제 확인'),
                      content: const Text('이 행사를 정말 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await FirebaseFirestore.instance.collection('events').doc(doc.id).delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('행사가 삭제되었습니다.')),
                      );
                      onDelete?.call(); // 삭제 후 목록 갱신
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('삭제 실패: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
