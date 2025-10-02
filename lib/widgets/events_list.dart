import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      return col.orderBy('createdAt', descending: true).limit(pageSize);
    } else {
      return col
          .where('status', isEqualTo: _statusFilter)
          .orderBy('priority')
          .orderBy('deadline')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || (more && _end)) return;
    setState(() { _loading = true; if (!more) _error = null; });
    try {
      Query<Map<String, dynamic>> q = _baseQuery();
      if (more && _last != null) q = q.startAfterDocument(_last!);
      final snap = await q.get();
      if (!more) _items.clear();
      _items.addAll(snap.docs);
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      _end = snap.docs.length < pageSize;
    } catch (e) {
      _error = e.toString();
      _end = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    return '-';
  }

  Future<void> _openEditor({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final refreshed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventEditor(docId: doc?.id, data: doc?.data()),
    );
    if (refreshed == true) {
      _last = null; _end = false;
      await _load(more: false);
    }
  }
  Future<void> _openDetail({required QueryDocumentSnapshot<Map<String, dynamic>> doc}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => EventDetail(docId: doc.id, data: doc.data()),
  );
}


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('행사 관리', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'active', child: Text('진행중(active)')),
                  DropdownMenuItem(value: 'inactive', child: Text('숨김(inactive)')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _statusFilter = v);
                  _last = null; _end = false;
                  await _load(more: false);
                },
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('행사 등록'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('오류: $_error', style: const TextStyle(color: Colors.red)),
          ),
Expanded(
  child: SingleChildScrollView(
    // 바깥은 세로 스크롤
    child: SingleChildScrollView(
      // ✅ 가로 스크롤 허용해서 오버플로우 제거
      scrollDirection: Axis.horizontal,
      child: DataTable(
        // 표 간격 조금 줄여서 여유 확보
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('제목')),
          DataColumn(label: Text('생성일')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('우선순위')),
          DataColumn(label: Text('마감일')),
          DataColumn(label: Text('')), // 액션(수정) 컬럼
        ],
        rows: _items.map((doc) {
          final d = doc.data();
          return DataRow(
             onSelectChanged: (_) => _openDetail(doc: doc), // ✅ 행 클릭 = 읽기 전용 상세
            // ✅ 행 클릭으로는 편집 안 열림 (onSelectChanged 제거)
            cells: [
              DataCell(Text(d['title']?.toString() ?? '-')),
              DataCell(Text(_fmtTs(d['createdAt']))),
              DataCell(Text(d['status']?.toString() ?? '-')),
              DataCell(Text((d['priority'] ?? '').toString())),
              DataCell(Text(_fmtTs(d['deadline']))),
              // ✅ 수정 버튼으로만 편집 열기
              DataCell(
                TextButton.icon(
                  onPressed: () => _openEditor(doc: doc),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  ),
),


               Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: (_loading || _end) ? null : () => _load(more: true),
            child: Text(_end ? '마지막 페이지' : '더 보기'),
          ),
        ),
      ],
    );
  }
}
