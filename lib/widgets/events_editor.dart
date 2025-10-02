import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class EventEditor extends StatefulWidget {
  final String? docId;                    // null이면 새로 만들기
  final Map<String, dynamic>? data;

  const EventEditor({super.key, this.docId, this.data});

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _priority = TextEditingController(text: '1');
  DateTime? _deadline;
  String _status = 'active';              // active | inactive
  bool _saving = false;

  // ===== 이미지 =====
  String? _imageUrl;                      // 저장된 URL (수정 모드에서 존재)
  Uint8List? _pickedImageBytes;           // 새로 선택한 이미지
  String? _pickedImageName;

  // ===== 첨부 =====
  final List<String> _attachments = [];   // 저장된 첨부 URL들
  List<PlatformFile> _pickedFiles = [];   // 새로 추가할 파일들

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    if (d != null) {
      _title.text   = d['title']?.toString() ?? '';
      _desc.text    = d['desc']?.toString() ?? '';
      _priority.text= (d['priority'] ?? 1).toString();
      _status       = (d['status']?.toString() ?? 'active');
      _imageUrl     = d['imageUrl'] as String?;
      final dl      = d['deadline'];
      if (dl is Timestamp) _deadline = dl.toDate();
      if (dl is String)    _deadline = DateTime.tryParse(dl);

      final atts = d['attachments'];
      if (atts is List) {
        _attachments
          ..clear()
          ..addAll(atts.cast<String>());
      }
    }
  }

  // ---------- 파일 선택 ----------
  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    setState(() { _pickedImageBytes = f.bytes; _pickedImageName = f.name; });
  }

  Future<void> _pickAttachments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf','doc','docx','ppt','pptx','xls','xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() { _pickedFiles = res.files; });
  }

  // ---------- 업로드 ----------
  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png'))  return 'image/png';
    if (n.endsWith('.gif'))  return 'image/gif';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.pdf'))  return 'application/pdf';
    if (n.endsWith('.doc'))  return 'application/msword';
    if (n.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (n.endsWith('.ppt'))  return 'application/vnd.ms-powerpoint';
    if (n.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (n.endsWith('.xls'))  return 'application/vnd.ms-excel';
    if (n.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    return 'application/octet-stream';
  }

  Future<String?> _uploadImage(String docId) async {
    // 새로 선택한 이미지가 없으면 (_pickedImageBytes == null) 현재 이미지 URL을 그대로 반환
    if (_pickedImageBytes == null) return _imageUrl;
    final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}_${_pickedImageName ?? 'image'}';
    final ref = FirebaseStorage.instance.ref('events/$docId/images/$fileName');
    await ref.putData(_pickedImageBytes!, SettableMetadata(contentType: _guessMime(_pickedImageName ?? 'jpg')));
    return await ref.getDownloadURL();
  }

  Future<List<String>> _uploadAttachments(String docId) async {
    final urls = <String>[];
    for (final f in _pickedFiles) {
      if (f.bytes == null) continue;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      final ref = FirebaseStorage.instance.ref('events/$docId/attachments/$fileName');
      await ref.putData(f.bytes!, SettableMetadata(contentType: _guessMime(f.name)));
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  // ---------- 삭제(이미지/첨부) ----------
  Future<void> _removeExistingImage() async {
    if (_imageUrl == null || _imageUrl!.isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.refFromURL(_imageUrl!);
      await ref.delete();             // Storage에서 삭제
    } catch (_) {
      // 파일이 이미 없을 수도 있으니 에러는 조용히 무시
    }
    setState(() {
      _imageUrl = null;               // Firestore에는 저장 시 null로 반영
      _pickedImageBytes = null;       // 새로 선택한 것도 비움
      _pickedImageName = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지를 삭제했습니다.')));
    }
  }

  Future<void> _removeExistingAttachment(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {}
    setState(() {
      _attachments.remove(url);       // Firestore에는 저장 시 리스트로 반영
    });
  }

  void _removePickedAttachment(PlatformFile f) {
    setState(() { _pickedFiles.remove(f); });
  }

  // ---------- 날짜 선택 ----------
  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context, initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    setState(() { _deadline = DateTime(d.year,d.month,d.day, t?.hour ?? 0, t?.minute ?? 0); });
  }

  // ---------- 저장/삭제 ----------
  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }
    setState(() => _saving = true);

    final col = FirebaseFirestore.instance.collection('events');
    String? docId = widget.docId;

    try {
      // 새 문서면 docId 먼저 확보(파일 경로에 필요)
      if (docId == null) {
        final draft = await col.add({
          'title': _title.text.trim(),
          'desc': _desc.text.trim(),
          'status': _status,
          'priority': int.tryParse(_priority.text.trim()) ?? 1,
          'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'imageUrl': null,
          'attachments': [],
        });
        docId = draft.id;
      }

      // 업로드(선택된 것만)
      final imageUrl = await _uploadImage(docId);
      final newAttUrls = await _uploadAttachments(docId);

      // 최종 첨부 목록(남겨둔 기존 + 새로 올린 것)
      final mergedAtts = [..._attachments, ...newAttUrls];

      // 최종 업데이트
      await col.doc(docId).update({
        'title': _title.text.trim(),
        'desc': _desc.text.trim(),
        'status': _status,
        'priority': int.tryParse(_priority.text.trim()) ?? 1,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'imageUrl': imageUrl,         // null이면 이미지 제거 처리
        'attachments': mergedAtts,    // 삭제 반영된 배열
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteDoc() async {
    if (widget.docId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('이 행사를 완전히 삭제합니다. (Storage 파일은 남을 수 있음)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.docId!).delete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePreview = _pickedImageBytes != null
        ? Image.memory(_pickedImageBytes!, height: 120, fit: BoxFit.cover)
        : (_imageUrl != null && _imageUrl!.isNotEmpty
            ? Image.network(_imageUrl!, height: 120, fit: BoxFit.cover)
            : const SizedBox(
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x11000000)),
                  child: Center(child: Text('이미지 미설정')),
                ),
              ));

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.docId == null ? '행사 등록' : '행사 수정',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (widget.docId != null)
              IconButton(onPressed: _deleteDoc, icon: const Icon(Icons.delete_outline)),
          ]),
          const SizedBox(height: 8),

          // ===== 이미지 섹션 =====
          ClipRRect(borderRadius: BorderRadius.circular(8), child: imagePreview),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('대표 이미지 선택'),
              ),
              const SizedBox(width: 8),
              if (_imageUrl != null && _imageUrl!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _removeExistingImage,                 // ✅ 이미지 삭제
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('이미지 삭제'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 12),
          TextField(controller: _title,
              decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _desc, maxLines: 4,
              decoration: const InputDecoration(labelText: '설명', border: OutlineInputBorder())),
          const SizedBox(height: 8),

          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('진행중(active)')),
                  DropdownMenuItem(value: 'inactive', child: Text('숨김(inactive)')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '상태'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _priority, keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '우선순위'),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          Row(children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '마감일(선택)'),
                child: Text(_deadline?.toString() ?? '미설정'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event),
              label: const Text('날짜 선택'),
            ),
          ]),

          const SizedBox(height: 12),

          // ===== 첨부 섹션 =====
          const Text('첨부파일 (PDF 등)'),
          const SizedBox(height: 6),
          // 기존에 저장돼 있던 첨부들 (삭제 가능)
          if (_attachments.isEmpty)
            const Text('저장된 첨부 없음')
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _attachments.map((url) {
                final name = Uri.tryParse(url)?.pathSegments.last ?? 'attachment';
                return Chip(
                  label: Text(name, overflow: TextOverflow.ellipsis),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () => _removeExistingAttachment(url),   // ✅ 기존 첨부 삭제
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          // 방금 추가하려는 첨부들(아직 업로드 전, 제거 가능)
          if (_pickedFiles.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _pickedFiles.map((f) {
                return Chip(
                  label: Text(f.name, overflow: TextOverflow.ellipsis),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () => _removePickedAttachment(f),       // ✅ 선택 취소
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(Icons.attach_file),
            label: const Text('첨부 선택(여러 개)'),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('저장'),
            ),
          ),
        ]),
      ),
    );
  }
}
