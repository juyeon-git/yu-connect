import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'admin_gate.dart';
import 'sign_up_screen.dart';           // 프로젝트의 로그인 위젯 경로/이름에 맞추세요
import 'firebase_options.dart';
import 'widgets/password_reset.dart';
import 'widgets/password_change.dart';

// ⬇️ 프로브용 페이지 (앞서 드린 lib/image_probe.dart 파일)
import 'image_probe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 프로브 기본 URL(없어도 동작은 함). 테스트할 때는 아래 값을
  // Firestore에 저장된 images[0] URL로 교체해도 되고,
  // Navigator.pushNamed(context, '/probe', arguments: '<URL>')로 전달해도 됩니다.
  static const String _defaultProbeUrl = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 웹 접속 시 바로 로그인 화면
      initialRoute: '/signIn',

      routes: {
        '/signIn': (context) => SignUpScreen(),     // 로그인/회원가입 화면
        '/admin':  (context) => const AdminGate(),  // 관리자 홈
        '/reset': (_) => const PasswordResetPage(),
        '/change-password': (_) => const PasswordChangePage(),

        // ✅ 이미지 단독 프로브 라우트
        // - 주소창에 #/probe 로 접근 가능
        // - 또는 Navigator.pushNamed(context, '/probe', arguments: '<테스트할 이미지 URL>')
        '/probe': (context) {
          final arg = ModalRoute.of(context)?.settings.arguments;
          final url = (arg is String && arg.isNotEmpty) ? arg : _defaultProbeUrl;
          return ImageProbePage(url: url);
        },
      },

      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C56D8),
        useMaterial3: true,
      ),
    );
  }
}
