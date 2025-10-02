import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'complaint_detail.dart';
import '../data/categories.dart';

class ComplaintsList extends StatefulWidget {
  const ComplaintsList({
    super.key,
    this.initialStatus,            // 'received' | 'processing' | 'inProgress' | 'done'
    this.initialMajor,             // '시설' | '학사'
    this.initialZone,              // 'A'..'G'
    this.initialBuildingCode,      // 'A01'.. 등
    this.lockFilters = false,      // true면 상단 필터바 숨김(고정 목록)
  });

  final String? initialStatus;
  final String? initialMajor;
  final String? initialZone;
  final String? initialBuildingCode;
  final bool lockFilters;

  @override
  State<ComplaintsList> createState() => _ComplaintsListState();
}

class _ComplaintsListState extends State<ComplaintsList> {
  static const int pageSize = 10;

  // 페이징 상태
  final _items = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _end = false;
  String? _error;

  // 필터 상태
  String? _statusFilter;        // null=전체
  String? _majorFilter;         // null=전체, '시설' | '학사'
  String? _zoneFilter;          // 'A'..'G'
  String? _buildingCodeFilter;  // 'B04' 등

  @override
  void initState() {
    super.initState();
    // 초기 필터 적용
    _statusFilter        = widget.initialStatus;
    _majorFilter         = widget.initialMajor;
    _zoneFilter          = widget.initialZone;
    _buildingCodeFilter  = widget.initialBuildingCode;

    _load(); // 초기 로딩
  }

  // ============================
  // Firestore Query Builder
  // ============================
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('complaints')
        .orderBy('createdAt', descending: true);

    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    if (_majorFilter != null) {
      q = q.where('category', isEqualTo: _majorFilter);
    }
    if (_majorFilter == '시설' && _zoneFilter != null) {
      q = q.where('zone', isEqualTo: _zoneFilter);
    }
    if (_majorFilter == '시설' && _buildingCodeFilter != null) {
      q = q.where('buildingCode', isEqualTo: _buildingCodeFilter);
    }
    return q;
  }

  // ============================
  // Paging Load
  // ============================
  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    if (more && _end) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> q = _buildQuery().limit(pageSize);
      if (more && _last != null) {
        q = q.startAfterDocument(_last!);
      }

      final snap = await q.get();
      if (!more) {
        _items.clear();
      }
      if (snap.docs.isNotEmpty) {
        _items.addAll(snap.docs);
        _last = snap.docs.last;
      }
      _end = snap.docs.length < pageSize;
    } catch (e) {
      _error = '목록을 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAndReload() {
    _items.clear();
    _last = null;
    _end = false;
    _error = null;
    _load();
  }

  // ============================
  // Helpers
  // ============================
  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  String _statusText(dynamic status) {
    final s = (status ?? '').toString();
    switch (s) {
      case 'received':
      case 'pending':      return '접수';
      case 'processing':
      case 'inProgress':   return '처리중';
      case 'done':         return '완료';
      default:             return s.isEmpty ? '-' : s;
    }
  }

  Color _statusColor(dynamic status) {
    final s = (status ?? '').toString();
    if (s == 'done') return Colors.green.shade600;
    if (s == 'processing' || s == 'inProgress') return Colors.orange.shade700;
    if (s == 'received' || s == 'pending') return Colors.blueGrey.shade600;
    return Colors.grey.shade600;
  }

  String _categoryText(Map<String, dynamic> d) {
    final cat = d['category'];
    if (cat == '시설') {
      final z = d['zone'];
      final code = d['buildingCode'];
      final name = d['buildingName'];
      if (z != null && code != null && name != null) {
        return '$cat · $z · $code $name';
      }
    }
    return (cat ?? '-').toString();
  }

  Future<void> _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ComplaintDetail(doc: doc),
        ),
      ),
    );
    _resetAndReload(); // 반영
  }

  // ============================
  // UI: Filter Bar
  // ============================
  Widget _buildFilterBar() {
    if (widget.lockFilters) return const SizedBox.shrink(); // 고정 목록 모드

    final buildings = (_majorFilter == '시설' && _zoneFilter != null)
        ? (kBuildingsByZone[_zoneFilter] ?? const [])
        : const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _statusFilter,
              hint: const Text('상태(전체)'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'received',   child: Text('접수(received)')),
                DropdownMenuItem(value: 'processing', child: Text('처리중(processing)')),
                DropdownMenuItem(value: 'inProgress', child: Text('처리중(inProgress)')),
                DropdownMenuItem(value: 'done',       child: Text('완료(done)')),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _resetAndReload();
              },
            ),
            DropdownButton<String>(
              value: _majorFilter,
              hint: const Text('대분류(전체)'),
              items: kMajors.map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) {
                setState(() {
                  _majorFilter = v;
                  _zoneFilter = null;
                  _buildingCodeFilter = null;
                });
                _resetAndReload();
              },
            ),
            if (_majorFilter == '시설')
              DropdownButton<String>(
                value: _zoneFilter,
                hint: const Text('구역(A~G)'),
                items: kZones.map<DropdownMenuItem<String>>((z) => DropdownMenuItem(value: z, child: Text('$z구역'))).toList(),
                onChanged: (v) {
                  setState(() {
                    _zoneFilter = v;
                    _buildingCodeFilter = null;
                  });
                  _resetAndReload();
                },
              ),
            if (_majorFilter == '시설')
              DropdownButton<String>(
                value: _buildingCodeFilter,
                hint: const Text('건물'),
                items: buildings
                    .map<DropdownMenuItem<String>>((b) => DropdownMenuItem(
                          value: b['code'],
                          child: Text('${b['code']} ${b['name']}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _buildingCodeFilter = v);
                  _resetAndReload();
                },
              ),
            if (_statusFilter != null ||
                _majorFilter != null ||
                _zoneFilter != null ||
                _buildingCodeFilter != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _statusFilter = null;
                    _majorFilter = null;
                    _zoneFilter = null;
                    _buildingCodeFilter = null;
                  });
                  _resetAndReload();
                },
                child: const Text('필터 초기화'),
              ),
          ],
        ),
      ),
    );
  }

  // ============================
  // UI: Table
  // ============================
  Widget _buildTable() {
    if (_error != null) return Center(child: Text(_error!));
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('표시할 민원이 없습니다.'));

    final rows = _items.map((doc) {
      final d = doc.data();
      final title = (d['title'] ?? '-').toString();
      final createdAt = _fmtTs(d['createdAt']);
      final statusTxt = _statusText(d['status']);
      final catTxt = _categoryText(d);

      return DataRow(
        cells: [
          DataCell(Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          DataCell(Text(catTxt)),
          DataCell(
            Row(
              children: [
                Container(
                  width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: _statusColor(d['status']), shape: BoxShape.circle),
                ),
                Text(statusTxt),
              ],
            ),
          ),
          DataCell(Text(createdAt)),
        ],
        onSelectChanged: (_) => _openDetail(doc),
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('제목')),
          DataColumn(label: Text('카테고리')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('작성일')),
        ],
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildTable()),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: (_loading || _end) ? null : () => _load(more: true),
            child: Text(_end ? '마지막 페이지' : (_loading ? '로딩 중...' : '더 보기')),
          ),
        ),
      ],
    );
  }
}
