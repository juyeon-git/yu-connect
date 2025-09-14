import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintDetail extends StatelessWidget {
  final String docId;
  const ComplaintDetail({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('complaints').doc(docId).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data() ?? {};
        String fmt(dynamic ts) =>
            ts is Timestamp ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '-';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['title']?.toString() ?? '-',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _row('상태', data['status']),
              _row('카테고리', data['category']),
              _row('작성자', data['createdBy'] ?? data['ownerUid']),
              _row('작성일', fmt(data['createdAt'])),
              const Divider(height: 24),
              const Text('내용', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(data['content']?.toString() ?? '-'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }
}
