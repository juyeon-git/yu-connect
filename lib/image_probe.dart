import 'package:flutter/material.dart';

class ImageProbePage extends StatelessWidget {
  const ImageProbePage({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    print('[ImageProbe] url = $url'); // 콘솔 확인용

    return Scaffold(
      appBar: AppBar(title: const Text('Image Probe')),
      body: Center(
        child: SizedBox(
          width: 360,
          height: 360,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            // 로딩 중일 때는 로딩 인디케이터
            loadingBuilder: (c, w, p) {
              if (p == null) return w;
              return const Center(child: CircularProgressIndicator());
            },
            // 에러 시 빨간 배경으로 표시
            errorBuilder: (c, e, st) => const ColoredBox(
              color: Color(0xFFFFEAEA),
              child: Center(
                child: Text('이미지 로드 실패', style: TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
