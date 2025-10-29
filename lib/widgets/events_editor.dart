import 'dart:html' as html; // 웹 업로드용
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class EventsEditor extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  const EventsEditor({super.key, this.doc});

  @override
  State<EventsEditor> createState() => _EventsEditorState();
}

class _EventsEditorState extends State<EventsEditor> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priorityController = TextEditingController(text: '1');
  final _capacityController = TextEditingController(text: '1'); // 정원

  bool _active = true;
  DateTime? _deadline;
  bool _applyEnabled = true;            // 신청 버튼 on/off
  bool _showInAppBanner = true;         // 배너 노출 on/off

  String _imageUrl = '';
  final List<String> _attachments = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final data = widget.doc!.data()!;
      _titleController.text = data['title'] ?? '';
      _descController.text = data['desc'] ?? '';
      _priorityController.text = '${data['priority'] ?? 1}';
      _active = (data['status'] ?? 'active') == 'active';
      _deadline = (data['deadline'] as Timestamp?)?.toDate();
      _applyEnabled = (data['applyEnabled'] as bool?) ?? true;
      _capacityController.text = '${data['capacity'] ?? 0}';
      _showInAppBanner =
          (data['isBanner'] as bool?) ??
          (data['showInAppBanner'] as bool?) ??
          true;
      _imageUrl = (data['imageUrl'] ?? '') as String? ?? '';
      final atts = data['attachments'];
      if (atts is List) {
        _attachments.addAll(atts.cast<String>());
      }
    }
  }

  Future<String?> _uploadToStorage(html.File file, String pathPrefix) async {
    final storage = FirebaseStorage.instance;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name}'.replaceAll(' ', '_');
    final ref = storage.ref().child('$pathPrefix/$fileName');

    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;
    late Uint8List bytes;
    if (result is Uint8List) {
      bytes = result;
    } else if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is List<int>) {
      bytes = Uint8List.fromList(result);
    } else {
      throw StateError('Unsupported reader.result type: ${result.runtimeType}');
    }

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: file.type),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> _pickBannerImage() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;
    setState(() => _saving = true);
    try {
      final url = await _uploadToStorage(file, 'events/banners');
      if (url != null) setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('배너 업로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachments() async {
    final input = html.FileUploadInputElement()..multiple = true;
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final file in input.files!) {
        final url = await _uploadToStorage(file, 'events/attachments');
        if (url != null) _attachments.add(url);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('첨부 업로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final capacity = int.tryParse(_capacityController.text) ?? 0;

      final data = {
        'title': _titleController.text.trim(),
        'desc': _descController.text.trim(),
        'status': _active ? 'active' : 'inactive',
        'priority': int.tryParse(_priorityController.text) ?? 1,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'applyEnabled': _applyEnabled,
        'capacity': _applyEnabled ? capacity : 0,     // off면 0 저장
        'imageUrl': _imageUrl,
        'attachments': _attachments,
        'isBanner': _showInAppBanner,
        'showInAppBanner': _showInAppBanner,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.doc == null) {
        await FirebaseFirestore.instance.collection('events').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'participants': <String>[],
          'participantsCount': 0,
        });
      } else {
        await widget.doc!.reference.update(data);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =========================
  // 🔻 삭제 관련 추가 코드
  // =========================
  Future<void> _deleteEvent() async {
    if (widget.doc == null) return;
    setState(() => _saving = true);
    try {
      final eventRef = widget.doc!.reference;

      // 1) participants 서브컬렉션 삭제
      await _deleteAllInSubcollection(eventRef.collection('participants'));

      // 2) 이벤트 문서 삭제
      await eventRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('행사가 삭제되었습니다.')),
      );
      Navigator.of(context).pop(); // 에디터 닫기
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteAllInSubcollection(
    CollectionReference<Map<String, dynamic>> col, {
    int pageSize = 300,
  }) async {
    while (true) {
      final snap = await col.limit(pageSize).get();
      if (snap.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      if (snap.docs.length < pageSize) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색으로 설정
      appBar: AppBar(
        title: Text(widget.doc == null ? '행사 등록' : '행사 수정'),
        backgroundColor: Colors.white, // 상단바 색상 흰색으로 설정
        surfaceTintColor: Colors.transparent, // 머티리얼3 틴트 제거
        elevation: 0, // 그림자 제거
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black, // 텍스트 색상 검정
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 대표 이미지(배너)
            InkWell(
              onTap: _pickBannerImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0x11000000),
                  borderRadius: BorderRadius.circular(12),
                  image: _imageUrl.isEmpty
                      ? null
                      : DecorationImage(image: NetworkImage(_imageUrl), fit: BoxFit.cover),
                ),
                child: _imageUrl.isEmpty
                    ? const Center(child: Text('대표 이미지 선택'))
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FilledButton.tonal(
                            onPressed: _pickBannerImage,
                            child: const Text('변경'),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // 배너 노출 토글
            SwitchListTile(
              title: const Text('앱 배너에 노출'),
              subtitle: const Text('대표 이미지를 앱 상단 배너 영역에 노출'),
              value: _showInAppBanner,
              onChanged: (v) => setState(() => _showInAppBanner = v),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '설명'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<bool>(
              value: _active,
              items: const [
                DropdownMenuItem(value: true, child: Text('진행중(active)')),
                DropdownMenuItem(value: false, child: Text('종료됨(inactive)')),
              ],
              onChanged: (v) => setState(() => _active = v ?? true),
              decoration: const InputDecoration(labelText: '상태'),
            ),
            const SizedBox(height: 12),

            // 신청 버튼 on/off
            SwitchListTile(
              title: const Text('버튼 비활성화=공지 등록'),
              value: _applyEnabled,
              onChanged: (v) {
                setState(() {
                  _applyEnabled = v;
                  if (!v) _capacityController.text = '0'; // off면 정원 0 고정
                });
              },
            ),
            const SizedBox(height: 12),

            // 정원 입력 (off면 비활성화)
            TextField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: '모집 정원(9999=정원 인원 제한X)'),
              keyboardType: TextInputType.number,
              enabled: _applyEnabled,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _priorityController,
              decoration: const InputDecoration(labelText: '우선순위'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    _deadline == null
                        ? '마감일(선택): 미설정'
                        : '마감일: ${_deadline!.toString().split(' ').first}',
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  child: const Text('날짜 선택'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 첨부파일
            Row(
              children: [
                Text('첨부파일', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('첨부 선택(여러 개)'),
                ),
              ],
            ),
            if (_attachments.isEmpty)
              const Text('저장된 첨부 없음')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map((url) => Chip(
                          label: Text(
                            Uri.parse(url).pathSegments.last,
                            overflow: TextOverflow.ellipsis),
                          onDeleted: () {
                            setState(() => _attachments.remove(url));
                          },
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue, // 버튼 색상 파란색
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}