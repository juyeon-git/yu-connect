import 'package:cloud_functions/cloud_functions.dart';

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
}
