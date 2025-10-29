import 'package:firebase_storage/firebase_storage.dart';

class StorageUrlResolver {
  static final _storage = FirebaseStorage.instance;

  /// 단일 문자열을 HTTPS URL로 보정
  /// - 이미 https면 그대로 반환
  /// - gs://.. 또는 complaints/<docId>/.. 형태면 getDownloadURL 수행
  static Future<String?> toHttps(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      return s; // 이미 다운로드 URL
    }

    // gs:// 버킷 경로 → 참조로 변환
    if (s.startsWith('gs://')) {
      final ref = _storage.refFromURL(s);
      return await ref.getDownloadURL();
    }

    // 상대 Storage 경로(예: complaints/<docId>/file.jpg)
    final ref = _storage.ref().child(s);
    return await ref.getDownloadURL();
  }

  /// Firestore images 필드(any→List<String>)를 안전하게 HTTPS 리스트로 변환
  static Future<List<String>> resolveList(dynamic imagesField) async {
    if (imagesField is! List) return const [];
    final results = <String>[];
    for (final e in imagesField) {
      final s = (e ?? '').toString();
      if (s.trim().isEmpty) continue;
      try {
        final url = await toHttps(s);
        if (url != null && url.isNotEmpty) results.add(url);
      } catch (err) {
        // 필요시 로깅
        // debugPrint('toHttps failed: $s → $err');
      }
    }
    return results;
  }
}
