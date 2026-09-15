import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 이 앱이 유지해야 할 성질을 실행 가능한 형태로 고정한다.
///
/// 전부 소스를 읽는 정적 검사다. 위젯도 서버도 띄우지 않는다.
/// 여기 있는 규칙은 CLAUDE.md 가 산문으로 적어 두던 것이고,
/// 셋 모두 어겨도 컴파일과 실행이 정상이라 조용히 지나간다.
void main() {
  String posix(FileSystemEntity e) =>
      e.path.replaceAll(Platform.pathSeparator, '/');

  List<File> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('모든 화면이 라우터에 등록돼 있다', () {
    // 화면 파일만 만들어도 아무 에러가 없다. 라우트만 생기지 않는다.
    final router = File('lib/app.dart').readAsStringSync();

    final unregistered = <String>[];
    for (final file in dartFilesUnder('lib/features')) {
      final name = posix(file).split('/').last;
      if (!name.endsWith('_screen.dart')) continue;

      // analyzing_screen.dart -> AnalyzingScreen
      final className = name
          .replaceAll('.dart', '')
          .split('_')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join();

      if (!router.contains(className)) {
        unregistered.add('$className (${posix(file)})');
      }
    }

    expect(unregistered, isEmpty,
        reason: '라우터에 등록되지 않은 화면이 있다. 파일만 만들면 라우트는 생기지 않는다 '
            '— lib/features/README.md 의 "화면을 만드는 규칙"');
  });

  test('서버 통신이 공통 인프라 바깥으로 새지 않는다', () {
    // 화면에서 직접 부르면 인증 헤더 처리와 응답 해석이 흩어지고,
    // 계약이 바뀔 때 빠뜨리는 곳이 생긴다.
    final offenders = dartFilesUnder('lib')
        .where((f) => f.readAsStringSync().contains("package:http/"))
        .map(posix)
        .where((p) => !p.startsWith('lib/core/services/'))
        .toList();

    expect(offenders, isEmpty,
        reason: 'HTTP 를 직접 부르는 곳은 lib/core/services 한 곳이어야 한다 '
            '— lib/core/README.md 의 "서버 통신 — 얇게 유지한다"');
  });

  test('서버가 정하는 열거값이 모델 바깥에 흩어져 있지 않다', () {
    // 값의 원본은 서버 저장소 README 의 계약 절이다. 앱은 한 곳에 타입으로
    // 정의해 재사용한다. 문자열로 흩뿌리면 서버가 값을 바꿀 때 전부 찾아야 한다.
    //
    // 검사할 어휘를 여기 적지 않고 모델 파일에서 뽑는다. 적어 두면 그 목록이
    // 또 하나의 사본이 되어 갈라진다.
    final model = File('lib/models/deed.dart').readAsStringSync();
    final vocabulary = RegExp("'([A-Z][A-Z_]{2,})'")
        .allMatches(model)
        .map((m) => m.group(1)!)
        .toSet();

    expect(vocabulary, isNotEmpty,
        reason: '모델에서 열거값 어휘를 찾지 못했다 — lib/features/README.md 의 "서버가 정하는 값"');

    final leaks = <String>[];
    for (final file in dartFilesUnder('lib')) {
      final path = posix(file);
      if (path.startsWith('lib/models/')) continue;

      final source = file.readAsStringSync();
      for (final value in vocabulary) {
        if (source.contains("'$value'")) leaks.add('$path → $value');
      }
    }

    expect(leaks, isEmpty,
        reason: '서버 열거값이 모델 밖에서 문자열로 쓰이고 있다 '
            '— lib/features/README.md 의 "서버가 정하는 값"');
  });
}
