import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'complaint_detail.dart';

class ComplaintsList extends StatefulWidget {
  const ComplaintsList({super.key});
  @override
  State<ComplaintsList> createState() => _ComplaintsListState();
}

class _ComplaintsListState extends State<ComplaintsList> {
  static const int pageSize = 10;
  final _items = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _end = false;

  Future<void> _load({bool more = false}) async {
    if (_loading || (more && _end)) return;
    setState(() => _loading = true);

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (more && _last != null) q = q.startAfterDocument(_last!);

    final snap = await q.get();
    if (!more) _items.clear();
    _items.addAll(snap.docs);

    if (snap.docs.isNotEmpty) {
      _last = snap.docs.last;
    }
    _end = snap.docs.length < pageSize;

    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('민원 리스트', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('제목')),
                DataColumn(label: Text('상태')),
                DataColumn(label: Text('작성자')),
                DataColumn(label: Text('작성일')),
              ],
              rows: _items.map((doc) {
                final d = doc.data();
                return DataRow(
                  onSelectChanged: (_) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ComplaintDetail(docId: doc.id),
                    );
                  },
                  cells: [
                    DataCell(Text(d['title']?.toString() ?? '-')),
                    DataCell(Text(d['status']?.toString() ?? '-')),
                    DataCell(Text(d['createdBy']?.toString() ?? d['ownerUid']?.toString() ?? '-')),
                    DataCell(Text(_fmtTs(d['createdAt']))),
                  ],
                );
              }).toList(),
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
