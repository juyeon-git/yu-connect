// lib/services/events_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EventsService {
  EventsService._();
  static final instance = EventsService._();

  /// 이벤트 삭제: Storage(대표 이미지+첨부) → participants 하위컬렉션 → 최종 문서 삭제
  Future<void> deleteEvent({
    required String eventId,
    String? imageUrl,
    List<String> attachments = const [],
  }) async {
    // 1) Storage 파일들 삭제 (오류는 개별 무시, 전체 진행)
    await _deleteStorageFiles(imageUrl: imageUrl, attachments: attachments);

    // 2) participants 하위컬렉션 삭제 (페이징 배치 커밋)
    await _deleteParticipantsSubcollection(eventId);

    // 3) 최종 이벤트 문서 삭제
    await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
  }

  // --- 내부 유틸들 ---

  Future<void> _deleteStorageFiles({
    String? imageUrl,
    List<String> attachments = const [],
  }) async {
    final storage = FirebaseStorage.instance;
    final futures = <Future<void>>[];

    Future<void> _deleteByUrl(String url) async {
      try {
        // 같은 버킷의 다운로드 URL이면 refFromURL로 바로 삭제 가능
        await storage.refFromURL(url).delete();
      } catch (_) {
        // 일부 URL은 refFromURL 실패할 수 있어 path로 복구 시도
        final path = _extractPathFromFirebaseUrl(url);
        if (path != null && path.isNotEmpty) {
          try {
            await storage.ref(path).delete();
          } catch (_) {
            // 파일이 없거나 권한 문제면 무시(논리적 삭제 우선)
          }
        }
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      futures.add(_deleteByUrl(imageUrl));
    }
    for (final u in attachments) {
      if (u is String && u.isNotEmpty) {
        futures.add(_deleteByUrl(u));
      }
    }
    await Future.wait(futures);
  }

  /// firebaseusercontent URL에서 Storage 경로 추출
  String? _extractPathFromFirebaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // 예: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encodedPath>?alt=...
      final seg = uri.pathSegments;
      final idx = seg.indexOf('o');
      if (idx >= 0 && idx + 1 < seg.length) {
        final encoded = seg[idx + 1];
        return Uri.decodeFull(encoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteParticipantsSubcollection(String eventId) async {
    final col = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('participants');

    const pageSize = 300;
    QueryDocumentSnapshot<Map<String, dynamic>>? last;

    while (true) {
      Query<Map<String, dynamic>> q = col.limit(pageSize);
      if (last != null) q = q.startAfterDocument(last);

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      last = snap.docs.isNotEmpty ? snap.docs.last : null;
      if (snap.docs.length < pageSize) break;
    }
  }
}
