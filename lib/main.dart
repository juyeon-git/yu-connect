import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'admin_gate.dart';
// 로그인 화면 파일/위젯 이름이 다르면 이 두 줄을 여러분 프로젝트에 맞게 변경하세요.
import 'sign_up_screen.dart'; // 예) 파일: lib/sign_in_screen.dart
// import 'login_screen.dart'; // 만약 여러분 프로젝트가 이렇게라면 위 줄 대신 이 줄

import 'firebase_options.dart'; // flutterfire configure로 생성된 파일
import 'widgets/password_reset.dart';
import 'widgets/password_change.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ 웹 접속 시 바로 로그인 화면부터 보여줍니다.
      initialRoute: '/signIn',

      routes: {
        // ⚠️ 여기도 const 쓰지 마세요(런타임 생성 위젯)
        '/signIn': (context) => SignUpScreen(), // ← 프로젝트 위젯명에 맞춰 변경
        '/admin':  (context) => const AdminGate(),
        '/reset': (_) => const PasswordResetPage(),
        '/change-password': (_) => const PasswordChangePage(),
      },

      // 테마는 원하시면 유지/수정
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C56D8),
        useMaterial3: true,
      ),
    );
  }
}
