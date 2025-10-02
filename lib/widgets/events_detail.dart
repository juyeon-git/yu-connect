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
    final imageUrl = (data['imageUrl'] ?? '') as String;
    final attachments = (data['attachments'] is List)
        ? (data['attachments'] as List).cast<String>()
        : const <String>[];

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('행사 상세', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // 썸네일
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isEmpty
                ? const SizedBox(
                    height: 140,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x11000000)),
                      child: Center(child: Text('이미지 없음')),
                    ),
                  )
                : Image.network(imageUrl, height: 140, fit: BoxFit.cover),
          ),

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
          const SizedBox(height: 12),

          // 첨부 목록
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
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('닫기'),
            ),
          ),
        ]),
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

  void _openUrl(String url) {
    // 웹에서 새 탭으로 열기
    html.window.open(url, '_blank');
  }
}
