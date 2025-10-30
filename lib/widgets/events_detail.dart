// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventDetail extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const EventDetail({super.key, required this.docId, required this.data});

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) return ts.toDate().toString();
    return ts?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '-';
    final desc = data['desc']?.toString() ?? '';
    final status = data['status']?.toString() ?? '-';
    final priority = (data['priority'] ?? '').toString();
    final deadline = _fmtTs(data['deadline']);
    final createdAt = _fmtTs(data['createdAt']);
    final imageUrl = (data['imageUrl'] ?? '') as String? ?? '';
    final attachments = (data['attachments'] is List)
        ? (data['attachments'] as List).cast<String>()
        : const <String>[];

    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색으로 설정
      appBar: AppBar(
        title: const Text('행사 상세'),
        backgroundColor: Colors.white, // 상단바 색상 흰색으로 설정
        surfaceTintColor: Colors.transparent, // 머티리얼3 틴트 제거
        elevation: 0, // 그림자 제거
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black, // 텍스트 색상 검정
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 배너
          _buildBanner(context, imageUrl),

          const SizedBox(height: 12),

          _kv('제목', title),
          const SizedBox(height: 6),
          _kv('설명', desc.isEmpty ? '-' : desc, multi: true),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: _kv('상태', status)),
            const SizedBox(width: 12),
            Expanded(child: _kv('우선순위', priority)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _kv('마감일', deadline)),
            const SizedBox(width: 12),
            Expanded(child: _kv('생성일', createdAt)),
          ]),

          const SizedBox(height: 16),

          // 신청 설정 토글
          Text('신청 설정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ApplyToggleSection(
            docId: docId,
            initial: (data['applyEnabled'] as bool?) ?? false,
          ),

          const SizedBox(height: 16),

          // 신청자 현황
          Text('신청 현황', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ParticipantsSection(
            participantUids: (data['participants'] as List?) ?? const [],
            eventId: docId,
          ),

          const SizedBox(height: 16),

          // 첨부
          Text('첨부', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (attachments.isEmpty)
            const Text('첨부 없음')
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: attachments.map((url) {
                final name = Uri.tryParse(url)?.pathSegments.last ?? 'attachment';
                return OutlinedButton.icon(
                  onPressed: () => _openUrl(url),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue, // 버튼 색상 파란색
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool multi = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      multi ? Text(v) : Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }

  void _openUrl(String url) => html.window.open(url, '_blank');
  // EventDetail 클래스 내부에 추가
Widget _buildBanner(BuildContext context, String imageUrl) {
  if (imageUrl.isEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: const SizedBox(
        height: 140,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0x11000000)),
          child: Center(child: Text('이미지 없음')),
        ),
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 140,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        // 로딩 중에는 스피너
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        // 실패 시 빨간 에러 텍스트 대신 깔끔한 대체 UI
        errorBuilder: (context, error, stackTrace) {
          return _BannerFallback(url: imageUrl);
        },
      ),
    ),
  );
}

}

class ApplyToggleSection extends StatefulWidget {
  const ApplyToggleSection({
    super.key,
    required this.docId,
    required this.initial,
  });

  final String docId;
  final bool initial;

  @override
  State<ApplyToggleSection> createState() => _ApplyToggleSectionState();
}

class _ApplyToggleSectionState extends State<ApplyToggleSection> {
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial;
  }

  Future<void> _update(bool value) async {
    setState(() {
      _enabled = value;
      _saving = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.docId)
          .update({
        'applyEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신청 버튼이 ${value ? '활성화' : '비활성화'}되었습니다.')),
        );
      }
    } catch (e) {
      setState(() => _enabled = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('변경 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _enabled ? '현재: 활성화' : '현재: 비활성화',
            style: TextStyle(
              color: _enabled ? Colors.green[700] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch.adaptive(
          value: _enabled,
          onChanged: _saving ? null : _update,
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}


class ParticipantsSection extends StatelessWidget {
  const ParticipantsSection({
    super.key,
    required this.participantUids,
    required this.eventId,
  });

  /// events 문서에 저장된 participants 배열 (없을 수도 있음)
  final List<dynamic> participantUids;

  /// 문서 ID (fallback 때 서브컬렉션 읽을 때 사용)
  final String eventId;

  @override
  Widget build(BuildContext context) {
    // 1) 문서의 배열을 우선 사용 (String/Map 섞여도 안전 처리)
    final uids = <String>[];
    for (final p in participantUids) {
      if (p is String) {
        uids.add(p);
      } else if (p is Map && p['uid'] is String) {
        uids.add(p['uid'] as String);
      }
    }

    // 2) 배열이 비어 있으면 -> 서브컬렉션 fallback (실시간)
    if (uids.isEmpty) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('participants')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (!snap.hasData) {
            return const Text('신청자 데이터를 불러오지 못했습니다.');
          }
          final docs = snap.data!.docs;
          final ids = docs
              .map((d) => (d.data()['uid'] ?? d.id).toString())
              .toList();
          return _ParticipantsList(uids: ids);
        },
      );
    }

    // 3) 배열이 있으면 그대로 사용
    return _ParticipantsList(uids: uids);
  }
}

class _ParticipantsList extends StatelessWidget {
  const _ParticipantsList({required this.uids});
  final List<String> uids;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('신청자 수: ${uids.length}명',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (uids.isEmpty) const Text('아직 신청자가 없습니다.'),
        for (final uid in uids)
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  dense: true,
                  leading: Icon(Icons.person_outline),
                  title: Text('불러오는 중...'),
                );
              }
              if (!snap.hasData || !snap.data!.exists) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_off),
                  title: Text('사용자 정보 없음 ($uid)'),
                );
              }
              final user = snap.data!.data()!;
              final name = (user['name'] ?? '') as String? ?? '';
              final sid = (user['studentId'] ?? '-') as String? ?? '-';
              final dept = (user['department'] ?? '') as String? ?? '';
              final email = (user['email'] ?? '') as String? ?? '';
              final phone = (user['phone'] ?? '-') as String? ?? '-'; // 전화번호 추가

              return ListTile(
                dense: true,
                leading: const Icon(Icons.person),
                title: Text('$name ($sid)'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept.isEmpty ? '학과 정보 없음' : dept),
                    Text('전화번호: $phone'), // 전화번호 표시
                  ],
                ),
                trailing: Text(email, overflow: TextOverflow.ellipsis),
              );
            },
          ),
      ],
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x11000000),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 28),
          const SizedBox(height: 8),
          const Text('이미지를 불러오지 못했습니다'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // 웹에서는 원본을 새 탭으로 열어 확인할 수 있게
              html.window.open(url, '_blank');
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('새 탭으로 보기'),
          ),
        ],
      ),
    );
  }
}