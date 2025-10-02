import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/categories.dart';
import 'complaints_list.dart';

/// 상태 탭에서 사용할 프리셋
const _kStatusTabs = <({String? label, String? value})>[
  (label: '전체',       value: null),
  (label: '접수',       value: 'received'),    // pending도 ComplaintsList가 처리중으로 매핑
  (label: '처리중',     value: 'inProgress'),  // processing/inProgress 혼용 커버
  (label: '완료',       value: 'done'),
];

class ComplaintsByCategoryPage extends StatelessWidget {
  const ComplaintsByCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('카테고리별 민원'),
          bottom: const TabBar(tabs: [
            Tab(text: '시설'),
            Tab(text: '학사'),
          ]),
        ),
        body: const TabBarView(
          children: [
            _FacilitiesTab(),
            _AcademicTab(),
          ],
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
              // 구역 전체 개수 뱃지
              _CountBadge(major: '시설', zone: zone),
              const Spacer(),
              // "구역 전체 보기" 버튼
              TextButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('구역 전체'),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _FixedStatusTabsPage(
                      title: '시설 · $zone구역 전체',
                      major: '시설',
                      zone: zone,
                      buildingCode: null,
                    ),
                  ));
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
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FixedStatusTabsPage(
                    title: '시설 · $zone · $code $name',
                    major: '시설',
                    zone: zone,
                    buildingCode: code,
                  ),
                ));
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
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _FixedStatusTabsPage(
                title: '학사 전체',
                major: '학사',
                zone: null,
                buildingCode: null,
              ),
            ));
          },
        ),
      ],
    );
  }
}

/// 상단에 상태 탭(전체/접수/처리중/완료)을 두고, 각 탭에서 ComplaintsList를
/// 고정 필터(lockFilters=true)로 보여주는 공용 페이지.
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
    return DefaultTabController(
      length: _kStatusTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            isScrollable: true,
            tabs: _kStatusTabs.map((t) => Tab(text: t.label)).toList(),
          ),
        ),
        body: TabBarView(
          children: _kStatusTabs.map((t) {
            return ComplaintsList(
              initialStatus: t.value,
              initialMajor: major,
              initialZone: zone,
              initialBuildingCode: buildingCode,
              lockFilters: true, // 상단 필터바 숨김(고정)
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Firestore count() API로 개수 뱃지(실패하면 조용히 미표시)
class _CountBadge extends StatelessWidget {
  const _CountBadge({this.major, this.zone, this.buildingCode});
  final String? major;
  final String? zone;
  final String? buildingCode;

  Future<int?> _count() async {
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('complaints');
      if (major != null)        q = q.where('category', isEqualTo: major);
      if (zone != null)         q = q.where('zone', isEqualTo: zone);
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
