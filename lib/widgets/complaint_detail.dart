import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class ComplaintDetail extends StatefulWidget {
  const ComplaintDetail({super.key, required this.doc});

  /// QueryDocumentSnapshot을 넘겨도 되고, DocumentSnapshot을 넘겨도 됩니다.
  final DocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<ComplaintDetail> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<ComplaintDetail> {
  late Map<String, dynamic> _data;
  late String _status; // received | inProgress | done
  final _replyCtrl = TextEditingController();
  bool _savingStatus = false;
  bool _savingReply = false;

  // 전체 화면 이미지 뷰어 인덱스
  int _viewerIndex = 0;

  // 이미지 URL 변환 Future(빌드마다 재계산 방지)
  late Future<List<String>> _imageUrlsFuture;

  // 새로 추가할 이미지 파일 리스트
  final List<XFile> _newImages = [];

  bool _isSubmitting = false;

  final Set<String> _urlsMarkedForDelete = {};

  @override
  void initState() {
    super.initState();
    _data = widget.doc.data() ?? <String, dynamic>{};
    _status = _normalizeStatus(_data['status']);

    _imageUrlsFuture = _resolveImageUrls(_data['images']);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  // ---------------- Helpers ----------------

  String _normalizeStatus(dynamic raw) {
    final s = (raw ?? '').toString();
    switch (s) {
      case 'received':
      case 'pending':
        return 'received';
      case 'processing':
      case 'inProgress':
        return 'inProgress';
      case 'done':
        return 'done';
      default:
        return 'received';
    }
  }

  String _statusLabel(String v) {
    switch (v) {
      case 'received':
        return '접수';
      case 'inProgress':
        return '처리중';
      case 'done':
        return '완료';
      default:
        return v;
    }
  }

  Color _statusColor(String v) {
    switch (v) {
      case 'received':
        return Colors.blueGrey.shade600;
      case 'inProgress':
        return Colors.orange.shade700;
      case 'done':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  /// 카테고리 뱃지: 앱이 저장한 평탄화 필드(category/zone/buildingCode/buildingName)를 그대로 사용
  Widget _categoryBadge(Map<String, dynamic> d) {
    final cat = d['category'];
    String text;
    if (cat == '시설') {
      final z = d['zone'];
      final code = d['buildingCode'];
      final name = d['buildingName'];
      if (z != null && code != null && name != null) {
        text = '$cat · $z · $code $name';
      } else {
        text = (cat ?? '-').toString();
      }
    } else {
      text = (cat ?? '-').toString(); // 학사 등
    }
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  /// 작성자 라인(작성자: 이름 학번 · 작성일: …)
  Widget _authorLine(String ownerUid, dynamic createdAtTs) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerUid).get(),
      builder: (context, snap) {
        String who = ownerUid; // fallback
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data()!;
          final name = (u['name'] ?? '').toString();
          final sid  = (u['studentId'] ?? '').toString();
          who = sid.isNotEmpty ? '$name ($sid)' : name;
        }
        return Row(
          children: [
            Text('작성자: $who'),
            const SizedBox(width: 12),
            Text('작성일: ${_fmtTs(createdAtTs)}'),
          ],
        );
      },
    );
  }

  // ======================== 이미지 처리 ========================

  /// Firestore images 필드(any)를 HTTPS URL 리스트로 변환
  /// - http(s)·gs:// 모두 안전하게 정규화 (`getDownloadURL()` 사용)
  /// - 쿼리파라미터는 보존하고 `cb`만 덧붙임(alt=media, token 유지)
  Future<List<String>> _resolveImageUrls(dynamic imagesField) async {
    // ignore: avoid_print
    print('[IMG] resolver start');
    final urls = <String>[];

    if (imagesField is! List) {
      // ignore: avoid_print
      print('[IMG] images 필드가 List가 아님: ${imagesField.runtimeType}');
      return urls;
    }

    final cacheBust = DateTime.now().millisecondsSinceEpoch.toString();

    // 파라미터 보존 + cb 추가
    String _withCb(String url) {
      final u = Uri.parse(url);
      final merged = <String, String>{...u.queryParameters, 'cb': cacheBust};
      return u.replace(queryParameters: merged).toString();
    }

    // Firebase download URL 파싱: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encPath>?...
    Map<String, String>? _parseFirebaseDownloadUrl(Uri u) {
      final segs = u.pathSegments;
      if (u.host == 'firebasestorage.googleapis.com' &&
          segs.length >= 5 &&
          segs[0] == 'v0' &&
          segs[1] == 'b' &&
          segs[3] == 'o') {
        final bucket = segs[2];
        final encPath = segs.sublist(4).join('/');
        final path = Uri.decodeComponent(encPath);
        return {'bucket': bucket, 'path': path};
      }
      return null;
    }

    for (var i = 0; i < imagesField.length; i++) {
      final raw = (imagesField[i] ?? '').toString().trim();
      if (raw.isEmpty) continue;

      try {
        // 1) gs://
        if (raw.startsWith('gs://')) {
          final ref = FirebaseStorage.instance.refFromURL(raw);
          final dl = await ref.getDownloadURL(); // alt=media & token 포함
          urls.add(_withCb(dl));
          // ignore: avoid_print
          print('[IMG][$i] gs:// → getDownloadURL OK');
          continue;
        }

        // 2) http(s)
        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          final u = Uri.parse(raw);

          // 2-a) Firebase download URL이면 버킷/경로 파싱 → ref.getDownloadURL() 재발급
          final parsed = _parseFirebaseDownloadUrl(u);
          if (parsed != null) {
            final storage =
                FirebaseStorage.instanceFor(bucket: 'gs://${parsed['bucket']}');
            final ref = storage.ref(parsed['path']!);
            final dl = await ref.getDownloadURL(); // 올바른 alt/token 보장
            urls.add(_withCb(dl));
            // ignore: avoid_print
            print('[IMG][$i] https(firebase) → 재발급 OK');
            continue;
          }

          // 2-b) 그 외 일반 URL은 파라미터 보존 + cb만 추가
          urls.add(_withCb(raw));
          // ignore: avoid_print
          print('[IMG][$i] http(s) non-firebase → pass');
          continue;
        }

        // 3) 상대 경로(complaints/.../file.jpg 등)
        final ref = FirebaseStorage.instance.ref().child(raw);
        final dl = await ref.getDownloadURL();
        urls.add(_withCb(dl));
        // ignore: avoid_print
        print('[IMG][$i] relative → getDownloadURL OK');
      } catch (e) {
        // ignore: avoid_print
        print('[IMG][$i] 변환 실패: $raw → $e');
        // 마지막 폴백(브라우저가 직접 열 수 있으면 열리게)
        urls.add(_withCb(raw));
      }
    }

    return urls;
  }

  /// 썸네일 그리드
  Widget _imageGrid(List<String> urls) {
    if (urls.isEmpty) {
      return const Text('첨부 이미지가 없습니다.', style: TextStyle(color: Colors.black54));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 한 줄 3개
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final url = urls[i];
        return InkWell(
          onTap: () => _openFullScreenViewer(urls, initialPage: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.cover,
              loadingBuilder: (c, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 26, height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (c, e, s) {
                // ignore: avoid_print
                print('[IMG][ERROR]\n$url → $e\n$s');
                return Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.center,
                  child: Text(
                    '이미지 로드 실패\n${url.length > 60 ? '${url.substring(0, 60)}...' : url}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade400, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 전체 화면 이미지 뷰어(스와이프/줌)
  Future<void> _openFullScreenViewer(List<String> urls, {int initialPage = 0}) async {
    final controller = PageController(initialPage: initialPage);
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) {
        int localIndex = initialPage;
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: urls.length,
                    onPageChanged: (i) {
                      localIndex = i;
                      setStateSB(() {});
                    },
                    itemBuilder: (_, i) {
                      final url = urls[i];
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.broken_image, color: Colors.white70, size: 64),
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${localIndex + 1} / ${urls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- Actions ----------------

  Future<void> _saveStatus() async {
    if (_savingStatus) return;
    setState(() => _savingStatus = true);
    try {
      await widget.doc.reference.update({
        'status': _status, // 표준값으로 저장
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 로컬 상태 갱신(재조회 없이도 반영되도록 최소 필드 보정)
      setState(() {
        _data['status'] = _status;
        _data['updatedAt'] = Timestamp.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _saveReply() async {
    if (_savingReply) return;
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;

    setState(() => _savingReply = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await widget.doc.reference.collection('replies').add({
        'message': msg,
        'senderUid': uid,
        'senderRole': 'admin', // 관리자에서 작성
        'createdAt': FieldValue.serverTimestamp(),
      });
      _replyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답변이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('답변 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReply = false);
    }
  }

  /// 새로 추가할 이미지 파일 리스트를 Firestore 문서에 업로드하고, 다운로드 URL 리스트를 반환
  Future<List<String>> uploadNewImages(String docId) async {
    final urls = <String>[];
    for (final x in _newImages) {
      final name = "${DateTime.now().millisecondsSinceEpoch}_${x.name}";
      final ref = FirebaseStorage.instance.ref("complaints/$docId/$name");

      // 업로드 수행
      await ref.putFile(
        File(x.path),
        SettableMetadata(
          contentType: _guessContentType(x.path),
          customMetadata: {
            'ownerUid': FirebaseAuth.instance.currentUser!.uid,
            'complaintId': docId,
          },
        ),
      );

      // URL 변환 및 저장
      try {
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('[ERROR] 이미지 URL 변환 실패: $e');
      }
    }
    return urls;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final title   = (_data['title'] ?? '-').toString();
    final owner   = (_data['ownerUid'] ?? '-').toString();
    final created = _data['createdAt'];

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
              const SizedBox(height: 6),

              // 메타: 작성자/작성일/상태
              Row(
                children: [
                  Expanded(child: _authorLine(owner, created)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(_status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(_status),
                      style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              // 카테고리 뱃지
              _categoryBadge(_data),

              const Divider(height: 24),

              // 본문
              Text('내용', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              SelectableText((_data['content'] ?? '-').toString()),
              const SizedBox(height: 16),

              // 첨부 이미지
              Text('첨부 이미지', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              FutureBuilder<List<String>>(
                future: _imageUrlsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text('이미지 로드 실패: ${snap.error}');
                  }
                  final urls = snap.data ?? const [];
                  return _imageGrid(urls);
                },
              ),

              const SizedBox(height: 20),

              // 상태 변경
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'received', child: Text('접수')),
                        DropdownMenuItem(value: 'inProgress', child: Text('처리중')),
                        DropdownMenuItem(value: 'done', child: Text('완료')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                      decoration: const InputDecoration(
                        labelText: '상태',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _savingStatus ? null : _saveStatus,
                    child: _savingStatus
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('상태 저장'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),

              // 답변 목록
              Text('답변 목록', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _RepliesList(parentRef: widget.doc.reference),

              const SizedBox(height: 12),

              // 답변 입력
              TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '답변 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveReply(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _savingReply ? null : _saveReply,
                  child: _savingReply
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('답변 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urlThumb(String url) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showImageViewer(url: url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('[ERROR] 이미지 로드 실패: $error');
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.red),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
            onPressed: _isSubmitting ? null : () => _removeExistingUrl(url),
          ),
        ),
      ],
    );
  }

  String _guessContentType(String path) {
    final mime = lookupMimeType(path) ?? 'image/jpeg';
    if (!mime.startsWith('image/')) return 'image/jpeg';
    return mime;
  }

  void _showImageViewer({File? file, String? url}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: file != null
                  ? Image.file(file)
                  : Image.network(url!, loadingBuilder: (_, child, prog) {
                      if (prog == null) return child;
                      return const CircularProgressIndicator(color: Colors.white);
                    }),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  void _removeExistingUrl(String url) {
    setState(() {
      _urlsMarkedForDelete.add(url);
    });
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({required this.parentRef});
  final DocumentReference<Map<String, dynamic>> parentRef;

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    return '-';
  }

  Widget _whoLabel(Map<String, dynamic> d) {
    final role = (d['senderRole'] ?? '').toString();
    if (role == 'admin') return const Text('관리자');

    final uid = (d['senderUid'] ?? '').toString();
    if (uid.isEmpty) return const Text('');

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        String who = uid;
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data()!;
          final nm = (u['name'] ?? '').toString();
          final sid = (u['studentId'] ?? '').toString();
          who = sid.isNotEmpty ? '$nm ($sid)' : nm;
        }
        return Text(who);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: parentRef
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('답변을 불러오는 중 오류가 발생했습니다: ${snap.error}');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const Text('등록된 답변이 없습니다.');

        final adminBubble = Theme.of(context).colorScheme.primaryContainer;
        final adminText = Theme.of(context).colorScheme.onPrimaryContainer;
        final userBubble = Theme.of(context).colorScheme.surfaceVariant;
        final userText = Theme.of(context).colorScheme.onSurfaceVariant;

        return Container(
          height: 300, // 스크롤 영역 높이 설정
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final r = docs[index];
              final d = r.data();
              final msg = (d['message'] ?? '').toString();
              final when = DateFormat('yyyy-MM-dd HH:mm')
                  .format(((d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()));
              final isAdmin = (d['senderRole'] ?? '') == 'admin';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment:
                      isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isAdmin) const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment:
                            isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            child: _whoLabel(d),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isAdmin ? adminBubble : userBubble,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(14),
                              ),
                            ),
                            child: Text(
                              msg,
                              style: TextStyle(
                                color: isAdmin ? adminText : userText,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            when,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                            textAlign: isAdmin ? TextAlign.right : TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin) const SizedBox(width: 6),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String firebaseFunctionUrl = 'https://<your-region>-<your-project-id>.cloudfunctions.net/getImage';

String imageUrl = '$firebaseFunctionUrl?url=<firebase-storage-url>';
