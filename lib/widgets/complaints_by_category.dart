// lib/widgets/complaints_by_category.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/categories.dart';
import 'complaints_list.dart';

/// 공통 패널 색상 (내부 카드 색)
const Color _panelBg = Color(0xFFF4F6F8); // 연한 회색 (내부 카드)
const Color _stroke = Color(0xFFE6EAF2);

/// 상태 탭 프리셋
const _kStatusTabs = <({String? label, String? value})>[
  (label: '전체', value: null),
  (label: '접수', value: 'received'),
  (label: '처리중', value: 'inProgress'),
  (label: '완료', value: 'done'),
];

class ComplaintsByCategoryPage extends StatelessWidget {
  const ComplaintsByCategoryPage({
    super.key,
    this.embedInOuterPanel = false,
  });

  /// embedInOuterPanel == true:
  ///  - 외부(관리자 레이아웃) 패널 안에서 렌더링됨(바깥 흰색, 안쪽만 연회색 카드)
  final bool embedInOuterPanel;

  @override
  Widget build(BuildContext context) {
    if (embedInOuterPanel) {
      // 관리자 레이아웃 내부에 포함될 때: 바깥은 이미 흰색, 안쪽만 연회색 카드
      return DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: TabBar(tabs: [Tab(text: '시설'), Tab(text: '학사')]),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _panelBg,
                  border: Border.all(color: _stroke),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: TabBarView(
                    children: [
                      _FacilitiesTab(),
                      _AcademicTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 단독 페이지 모드(새 Scaffold). 상단 분홍 틴트 제거를 위해 Theme로 감싼다.
    final base = Theme.of(context);
    final fixed = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: base.colorScheme.copyWith(surface: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
      ),
    );

    return Theme(
      data: fixed,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('카테고리별 민원'),
            bottom: const TabBar(tabs: [Tab(text: '시설'), Tab(text: '학사')]),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border.all(color: _stroke),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: TabBarView(
                  children: [
                    _FacilitiesTab(),
                    _AcademicTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacilitiesTab extends StatelessWidget {
  const _FacilitiesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: kZones.map((zone) {
        final buildings = kBuildingsByZone[zone] ?? const [];
        return ExpansionTile(
          title: Row(
            children: [
              Text('$zone구역'),
              const SizedBox(width: 8),
              _CountBadge(major: '시설', zone: zone),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('구역 전체'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FixedStatusTabsPage(
                        title: '시설 · $zone구역 전체',
                        major: '시설',
                        zone: zone,
                        buildingCode: null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          children: buildings.map((b) {
            final code = b['code']!;
            final name = b['name']!;
            return ListTile(
              title: Text('$code $name'),
              trailing: _CountBadge(major: '시설', zone: zone, buildingCode: code),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FixedStatusTabsPage(
                      title: '시설 · $zone · $code $name',
                      major: '시설',
                      zone: zone,
                      buildingCode: code,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _AcademicTab extends StatelessWidget {
  const _AcademicTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('학사 전체'),
          trailing: const _CountBadge(major: '학사'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _FixedStatusTabsPage(
                  title: '학사 전체',
                  major: '학사',
                  zone: null,
                  buildingCode: null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 상세 탭 페이지 (구역 전체 / 건물별 등)
class _FixedStatusTabsPage extends StatelessWidget {
  const _FixedStatusTabsPage({
    required this.title,
    required this.major,
    required this.zone,
    required this.buildingCode,
  });

  final String title;
  final String? major;
  final String? zone;
  final String? buildingCode;

  @override
  Widget build(BuildContext context) {
    // 새 라우트(Scaffold)에서도 상단 분홍 틴트가 생기지 않도록 Theme으로 강제
    final base = Theme.of(context);
    final fixed = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: base.colorScheme.copyWith(surface: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
      ),
    );

    return Theme(
      data: fixed,
      child: DefaultTabController(
        length: _kStatusTabs.length,
        child: Scaffold(
          backgroundColor: Colors.white, // 바깥 전체 흰색
          appBar: AppBar(
            title: Text(title),
            bottom: TabBar(
              isScrollable: true,
              tabs: _kStatusTabs.map((t) => Tab(text: t.label)).toList(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: _panelBg, // 내부 카드(연회색)
                border: Border.all(color: _stroke),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TabBarView(
                  children: _kStatusTabs.map((t) {
                    return ComplaintsList(
                      embedInOuterPanel: true,
                      initialStatus: t.value,
                      initialMajor: major,
                      initialZone: zone,
                      initialBuildingCode: buildingCode,
                      lockFilters: true,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Firestore count() API로 개수 뱃지(실패 시 숨김)
class _CountBadge extends StatelessWidget {
  const _CountBadge({this.major, this.zone, this.buildingCode});
  final String? major;
  final String? zone;
  final String? buildingCode;

  Future<int?> _count() async {
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('complaints');
      if (major != null) q = q.where('category', isEqualTo: major);
      if (zone != null) q = q.where('zone', isEqualTo: zone);
      if (buildingCode != null) q = q.where('buildingCode', isEqualTo: buildingCode);
      final snap = await q.count().get();
      return snap.count;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _count(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final n = snap.data!;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$n'),
        );
      },
    );
  }
}
