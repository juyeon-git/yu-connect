import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFunctions {
  static final _fns = FirebaseFunctions.instance;

  static Future<void> bootstrapSuperAdmin() async {
    final callable = _fns.httpsCallable('bootstrapSuperAdmin');
    await callable.call();
  }

  static Future<void> approve(String targetUid) async {
    final callable = _fns.httpsCallable('approveAdmin');
    await callable.call({'targetUid': targetUid});
  }

  static Future<void> reject(String targetUid) async {
    final callable = _fns.httpsCallable('rejectAdmin');
    await callable.call({'targetUid': targetUid});
  }
   /// 관리자 신청/문서 삭제 (admins/{uid} 제거)
  static Future<void> remove(String uid) async {
    await FirebaseFirestore.instance
        .collection('admins')
        .doc(uid)
        .delete();
  }
}
