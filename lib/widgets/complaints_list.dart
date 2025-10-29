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
    this.embedInOuterPanel = false,
  });

  final String? initialStatus;
  final String? initialMajor;
  final String? initialZone;
  final String? initialBuildingCode;
  final bool lockFilters;
  final bool embedInOuterPanel;

  @override
  State<ComplaintsList> createState() => _ComplaintsListState();
}

class _ComplaintsListState extends State<ComplaintsList> {
  // ===== 스타일(단독 사용 시) =====
  static const Color _panelBg = Color(0xFFF4F6F8);
  static const Color _stroke  = Color(0xFFE6EAF2);

  // ===== 페이지네이션 =====
  static const int _pageSize = 10;

  // 현재 페이지 문서들
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rows = [];

  // 각 페이지 마지막 문서 커서 (1페이지의 커서는 rows.last)
  // _cursors[n] = (n+1) 페이지의 마지막 문서
  final List<DocumentSnapshot<Map<String, dynamic>>> _cursors = [];

  int _page = 1;          // 현재 페이지 (1부터)
  bool _hasNext = false;  // 다음 페이지 존재 여부
  bool _loading = false;
  String? _error;

  // ===== 필터 상태 =====
  String? _statusFilter;
  String? _majorFilter;
  String? _zoneFilter;
  String? _buildingCodeFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter       = widget.initialStatus;
    _majorFilter        = widget.initialMajor;
    _zoneFilter         = widget.initialZone;
    _buildingCodeFilter = widget.initialBuildingCode;
    _resetAndLoad(); // 최초 1페이지 로드
  }

  // ===== 쿼리 생성 =====
  Query<Map<String, dynamic>> _baseQuery() {
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

  // ===== 페이지 읽기 =====
  Future<void> _loadPage(int toPage) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 항상 limit은 pageSize+1로 가져와서 다음 페이지 유무를 판단
      Query<Map<String, dynamic>> q = _baseQuery().limit(_pageSize + 1);

      // 2페이지 이상이면 해당 페이지 시작 커서 필요
      if (toPage > 1) {
        // (toPage-1) 페이지의 시작점은 (toPage-2) 페이지의 마지막 문서
        // _cursors[i]는 i+1 페이지의 마지막 문서이므로,
        // toPage가 2면 _cursors[0]를 startAfter로 사용
        final cursorIndex = (toPage - 2);
        if (cursorIndex < 0 || cursorIndex >= _cursors.length) {
          // 커서가 없으면(비정상 진입) 1페이지로 리셋
          return _resetAndLoad();
        }
        q = q.startAfterDocument(_cursors[cursorIndex]);
      }

      final snap = await q.get();
      final docs = snap.docs;

      _hasNext = docs.length > _pageSize;                 // 다음 페이지 존재 여부
      final pageDocs = docs.take(_pageSize).toList();     // 이번 페이지 문서

      // 커서 스택 갱신 (해당 페이지의 마지막 문서 저장)
      if (_cursors.length < toPage) {
        if (pageDocs.isNotEmpty) {
          _cursors.add(pageDocs.last);
        } else {
          // 비어 있으면 커서 추가 안 함
        }
      } else {
        // 현재 페이지 커서 갱신(필터 변경 후 재방문 등)
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

  // ===== 헬퍼 =====
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
    // 상세에서 변경이 있을 수 있으므로 현재 페이지를 새로고침
    await _loadPage(_page);
  }

  // ===== UI: 필터바 =====
  Widget _buildFilterBar() {
    if (widget.lockFilters) return const SizedBox.shrink();

    final buildings = (_majorFilter == '시설' && _zoneFilter != null)
        ? (kBuildingsByZone[_zoneFilter] ?? const [])
        : const [];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _stroke),
        borderRadius: BorderRadius.circular(8),
      ),
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
                DropdownMenuItem(value: 'pending',    child: Text('접수')),
                DropdownMenuItem(value: 'inProgress', child: Text('처리중')),
                DropdownMenuItem(value: 'done',       child: Text('완료')),
              ],
              onChanged: (v) async {
                setState(() => _statusFilter = v);
                await _resetAndLoad();
              },
            ),
            DropdownButton<String>(
              value: _majorFilter,
              hint: const Text('대분류(전체)'),
              items: kMajors
                  .map<DropdownMenuItem<String>>(
                      (m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _majorFilter = v;
                  _zoneFilter = null;
                  _buildingCodeFilter = null;
                });
                await _resetAndLoad();
              },
            ),
            if (_majorFilter == '시설')
              DropdownButton<String>(
                value: _zoneFilter,
                hint: const Text('구역(A~G)'),
                items: kZones
                    .map<DropdownMenuItem<String>>((z) =>
                        DropdownMenuItem(value: z, child: Text('$z구역')))
                    .toList(),
                onChanged: (v) async {
                  setState(() {
                    _zoneFilter = v;
                    _buildingCodeFilter = null;
                  });
                  await _resetAndLoad();
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
                onChanged: (v) async {
                  setState(() => _buildingCodeFilter = v);
                  await _resetAndLoad();
                },
              ),
            if (_statusFilter != null ||
                _majorFilter != null ||
                _zoneFilter != null ||
                _buildingCodeFilter != null)
              TextButton(
                onPressed: () async {
                  setState(() {
                    _statusFilter = null;
                    _majorFilter = null;
                    _zoneFilter = null;
                    _buildingCodeFilter = null;
                  });
                  await _resetAndLoad();
                },
                child: const Text('필터 초기화'),
              ),
          ],
        ),
      ),
    );
  }

  // ===== UI: 테이블 =====
  Widget _buildTable() {
    if (_error != null) return Center(child: Text(_error!));
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) return const Center(child: Text('표시할 민원이 없습니다.'));

    final rows = _rows.map((doc) {
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
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _statusColor(d['status']),
                    shape: BoxShape.circle,
                  ),
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

  // ===== 하단 페이지 네비게이션 =====
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

  // ===== 본문 =====
  Widget _buildBody() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildTable()),
        _buildPaginator(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embedInOuterPanel) {
      // 부모 패널 안에 포함되는 모드: 내용만 반환
      return body;
    }

    // 단독 사용 시: 중앙 정렬 + 연회색 패널
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _panelBg,
            border: Border.all(color: _stroke),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: body,
        ),
      ),
    );
  }
}
