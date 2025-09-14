import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fui;
import 'widgets/complaints_list.dart';

const adminEmails = {
  'admin@school.ac.kr', 'kjy020720@gmail.com'
};

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // ← 로그인/로그아웃 즉시 반영
      builder: (context, snapshot) {
        final user = snapshot.data;

        // 1) 미로그인: 로그인 화면
        if (user == null) {
          return fui.SignInScreen(
            providers: [fui.EmailAuthProvider()],
          );
        }

        // 2) 관리자 판정(대소문자/공백 무시)
        final email = user.email?.trim().toLowerCase();
        final isAdmin = email != null &&
            adminEmails.map((e) => e.trim().toLowerCase()).contains(email);

        // 3) 권한 없음
        if (!isAdmin) {
          return const Scaffold(
            body: Center(child: Text('관리자만 접근 가능합니다.')),
          );
        }

        // 4) 통과
        return const AdminHomePage();
      },
    );
  }
}

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});
  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        title: const Text('YU-Connect Admin'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: const Padding(
        padding: const EdgeInsets.all(8.0),
        child:  ComplaintsList(),
      ),
    );
  }
}
