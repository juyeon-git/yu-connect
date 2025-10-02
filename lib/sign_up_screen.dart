import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  // 로그인
  final _loginEmail = TextEditingController();
  final _loginPw = TextEditingController();
  bool _loginLoading = false;
  String? _loginError;

  // 회원가입
  final _name = TextEditingController();
  final _dept = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _signingUp = false;
  String? _signUpError;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPw.dispose();
    _name.dispose();
    _dept.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  // ---------------- 로그인 ----------------
  Future<void> _signIn() async {
    if (_loginLoading) return;
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmail.text.trim(),
        password: _loginPw.text,
      );
      if (!mounted) return;
      // 로그인 성공 → 관리자 게이트로
      Navigator.pushReplacementNamed(context, '/admin');
    } on FirebaseAuthException catch (e) {
      setState(() => _loginError = e.message ?? '로그인 실패');
    } catch (e) {
      setState(() => _loginError = '로그인 중 오류: $e');
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ---------------- 관리자 회원가입 ----------------
  Future<void> _signUp() async {
    if (_signingUp) return;
    if (_pw.text != _pw2.text) {
      setState(() => _signUpError = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (_name.text.trim().isEmpty || _dept.text.trim().isEmpty) {
      setState(() => _signUpError = '이름과 소속을 입력하세요.');
      return;
    }

    setState(() {
      _signingUp = true;
      _signUpError = null;
    });

    try {
      // 1) Auth 사용자 생성
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
      final uid = cred.user!.uid;

      // 2) Firestore users/{uid} 문서 생성 (역할: admin)
      final now = FieldValue.serverTimestamp();
      // users/{uid} → 참고용 기본 정보만 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _email.text.trim(),
        'name': _name.text.trim(),
        'dept': _dept.text.trim(),
        'createdAt': now,
        'updatedAt': now,
        'fcmTokens': [],
      }, SetOptions(merge: true));

// admins/{uid} → 승인 절차를 위한 문서 생성
await FirebaseFirestore.instance.collection('admins').doc(uid).set({
  'uid': uid,
  'email': _email.text.trim(),
  'name': _name.text.trim(),
  'dept': _dept.text.trim(),
  'role': 'pending',        // ★ 승인 대기 상태
  'createdAt': now,
  'approvedBy': null,
});


      if (!mounted) return;
      // 3) 바로 관리자 게이트로 진입
      Navigator.pushReplacementNamed(context, '/admin');
    } on FirebaseAuthException catch (e) {
      setState(() => _signUpError = e.message ?? '회원가입 실패');
    } catch (e) {
      setState(() => _signUpError = '회원가입 중 오류: $e');
    } finally {
      if (mounted) setState(() => _signingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YU-Connect Admin'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '로그인'), Tab(text: '관리자 회원가입')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ---------------- 로그인 탭 ----------------
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _loginEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _loginPw,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                    const SizedBox(height: 12),
                    if (_loginError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_loginError!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loginLoading ? null : _signIn,
                        child: _loginLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('로그인'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------------- 관리자 회원가입 탭 ----------------
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dept,
                      decoration: const InputDecoration(
                        labelText: '소속',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pw,
                      obscureText: _obscure1,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure1 = !_obscure1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pw2,
                      obscureText: _obscure2,
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure2 = !_obscure2),
                        ),
                      ),
                      onSubmitted: (_) => _signUp(),
                    ),
                    const SizedBox(height: 12),
                    if (_signUpError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_signUpError!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signingUp ? null : _signUp,
                        child: _signingUp
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('관리자 회원가입'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
