import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// =====================
/// Branding (색상/로고)
/// =====================
const kBrandBlue = Color(0xFF1A73E8); // YU 파란색

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final yu = TextStyle(
      color: kBrandBlue,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      fontSize: compact ? 24 : 28,
    );
    final sub = TextStyle(
      color: kBrandBlue, // ← 색상 통일
      fontWeight: FontWeight.w500,
      fontSize: compact ? 14 : 16,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('YU', style: yu),
        const SizedBox(width: 8),
        Text('connect your campus', style: sub),
      ],
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
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
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
      final uid = cred.user!.uid;

      await cred.user!.updateDisplayName(_name.text.trim());

      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        'uid': uid,
        'email': _email.text.trim(),
        'name': _name.text.trim(),
        'dept': _dept.text.trim(),
        'role': 'pending',
        'createdAt': now,
        'updatedAt': now,
        'approvedBy': null,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin');
    } on FirebaseAuthException catch (e) {
      setState(() => _signUpError = e.message ?? '회원가입 실패');
    } catch (e) {
      setState(() => _signUpError = '회원가입 중 오류: $e');
    } finally {
      if (mounted) setState(() => _signingUp = false);
    }
  }

  ButtonStyle _primaryFilledButton() => FilledButton.styleFrom(
        backgroundColor: kBrandBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  ButtonStyle _linkStyle() =>
      TextButton.styleFrom(foregroundColor: kBrandBlue);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 바탕 흰색
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const BrandLogo(), // 상단 로고만 표시
        centerTitle: false,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: kBrandBlue,
          dividerColor: Colors.grey.shade200,
          labelColor: kBrandBlue,
          unselectedLabelColor: Colors.black54,
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
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✨ 여기서 로고 제거됨
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
                        child: Text(
                          _loginError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: _primaryFilledButton(),
                        onPressed: _loginLoading ? null : _signIn,
                        child: _loginLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('로그인'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: _linkStyle(),
                      onPressed: () => Navigator.pushNamed(context, '/reset'),
                      child: const Text('비밀번호 찾기'),
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
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
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
                          icon: Icon(
                              _obscure1 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure1 = !_obscure1),
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
                          icon: Icon(
                              _obscure2 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure2 = !_obscure2),
                        ),
                      ),
                      onSubmitted: (_) => _signUp(),
                    ),
                    const SizedBox(height: 12),
                    if (_signUpError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _signUpError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: _primaryFilledButton(),
                        onPressed: _signingUp ? null : _signUp,
                        child: _signingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
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
