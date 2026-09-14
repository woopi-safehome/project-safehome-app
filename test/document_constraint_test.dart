import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 문서가 가리키는 곳이 실제로 있는지 검사한다.
///
/// 문서는 어긋나도 빌드가 멀쩡하다. 여기서는 그중 기계가 판정할 수 있는 것만 본다 —
/// 링크, 인용한 절, 계약 표식, 머리글과 문서 지도, 제약 테스트가 실패 메시지에 적은 근거 문서.
/// 문장이 코드 동작에 대해 사실인지는 보지 못한다. 그것은 CLAUDE.md 의 필수 절차가 맡는다.
///
/// 검사 대상을 목록으로 적지 않고 저장소를 걸어서 찾는다. 목록은 또 하나의 사본이 되어 갈라진다.
/// 그래서 검사마다 대상을 하나 이상 찾았는지 먼저 본다. 찾지 못하면 문제 목록이 비어
/// 아무것도 보지 않은 채 통과한다.
void main() {
  final root = Directory.current.absolute.uri;
  final readme = root.resolve('README.md');

  bool skipped(String name) =>
      name.startsWith('.') || name == 'build' || name == 'node_modules';

  List<Uri> filesUnder(Uri dir, String suffix) {
    final found = <Uri>[];
    final directory = Directory.fromUri(dir);
    if (!directory.existsSync()) return found;
    for (final entity in directory.listSync()) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is Directory) {
        if (!skipped(name)) found.addAll(filesUnder(entity.absolute.uri, suffix));
      } else if (entity is File && name.endsWith(suffix)) {
        found.add(entity.absolute.uri);
      }
    }
    return found;
  }

  String rel(Uri uri) =>
      Uri.decodeFull(uri.path).substring(Uri.decodeFull(root.path).length);
  bool inRepo(Uri uri) => uri.path.startsWith(root.path);
  bool isFile(Uri uri) => File.fromUri(uri).existsSync();
  List<String> linesOf(Uri uri) => File.fromUri(uri).readAsLinesSync();

  final docs = filesUnder(root, '.md');
  final testSources = filesUnder(root.resolve('test/'), '.dart');
  final constraintTests =
      testSources.where((u) => u.path.endsWith('constraint_test.dart')).toList();

  // 저장소 밖을 가리키는 경로는 워크스페이스에 함께 있을 때만 유효하므로 검사하지 않는다
  bool leavesRepo(String ref, Uri from) => !inRepo(from.resolve(ref));

  // 적힌 자리 기준, 저장소 루트 기준, 경로 끝이 일치하는 문서가 하나뿐인 경우 순으로 찾는다
  Uri? resolveDoc(String ref, [Uri? from]) {
    if (from != null && isFile(from.resolve(ref))) return from.resolve(ref);
    if (isFile(root.resolve(ref))) return root.resolve(ref);
    final hits = docs.where((d) => rel(d).endsWith('/$ref')).toList();
    return hits.length == 1 ? hits.single : null;
  }

  String clean(String s) => s.replaceAll('**', '').replaceAll('`', '').trim();

  final headingLine = RegExp(r'^(#{1,6})\s+(.+)$');

  // 코드 블록 밖의 제목들: (줄 번호, 단계, 제목)
  List<(int, int, String)> headingsOf(List<String> lines) {
    var fenced = false;
    final out = <(int, int, String)>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('```')) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      final m = headingLine.firstMatch(lines[i]);
      if (m != null) out.add((i, m.group(1)!.length, clean(m.group(2)!)));
    }
    return out;
  }

  int sectionEnd(
          List<String> lines, List<(int, int, String)> headings, (int, int, String) start) =>
      headings
          .where((h) => h.$1 > start.$1 && h.$2 <= start.$2)
          .map((h) => h.$1)
          .firstOrNull ??
      lines.length;

  // "절 - 항목" 형태면 앞은 제목에, 뒤는 본문 어딘가에 있어야 한다
  bool cites(Uri doc, String section) {
    final parts = clean(section).split(' - ');
    final lines = linesOf(doc);
    return headingsOf(lines).any((h) => h.$3.contains(parts.first)) &&
        parts.skip(1).every((part) => lines.any((l) => l.contains(part)));
  }

  final link = RegExp(r'\]\(([^)\s]+)\)');
  const sectionName =
      r'(?:"([^"]+)"|\*\*([^*]+)\*\*|([^\s"*]+(?: [^\s"*]+)?) 절(?!차))';
  final docCitation = RegExp(r'([A-Za-z0-9_./-]+\.md)[`)]? ?의 ' + sectionName);
  final readmeCitation = RegExp(r'README ?의 ' + sectionName);
  final localCitation = RegExp(r'(?:위|아래) (?:"([^"]+)"|\*\*([^*]+)\*\*)');

  String cited(RegExpMatch m, int from) {
    for (var i = from; i <= m.groupCount; i++) {
      final g = m.group(i);
      if (g != null && g.isNotEmpty) return g;
    }
    return '';
  }

  List<Uri>? mappedDocs() {
    final lines = linesOf(readme);
    final headings = headingsOf(lines);
    final start = headings.where((h) => h.$3.contains('문서 지도')).firstOrNull;
    if (start == null) return null;
    return lines
        .sublist(start.$1, sectionEnd(lines, headings, start))
        .expand((l) => link.allMatches(l))
        .map((m) => root.resolve(m.group(1)!.split('#').first))
        .where((u) => u.pathSegments.last != 'CLAUDE.md')
        .toList();
  }

  test('문서의 링크가 가리키는 파일이 있다', () {
    final internal = <(Uri, String, String)>[];
    for (final doc in docs) {
      for (final m in link.allMatches(File.fromUri(doc).readAsStringSync())) {
        final target = m.group(1)!.split('#').first;
        final external = target.isEmpty ||
            ['http:', 'https:', 'mailto:'].any((p) => target.startsWith(p));
        if (external || leavesRepo(target, doc)) continue;
        internal.add((doc, m.group(1)!, target));
      }
    }
    expect(internal, isNotEmpty,
        reason: '링크를 하나도 찾지 못하면 아무것도 보지 않고 통과한다 — CLAUDE.md');

    final broken = internal
        .where((l) =>
            FileSystemEntity.typeSync(l.$1.resolve(l.$3).toFilePath()) ==
            FileSystemEntityType.notFound)
        .map((l) => '${rel(l.$1)} → ${l.$2}')
        .toList();
    expect(broken, isEmpty,
        reason: '경로를 옮기면 그곳을 가리키는 문서도 함께 고친다 — CLAUDE.md');
  });

  test('문서와 테스트에 적힌 문서 경로가 있다', () {
    final backticked = RegExp(r'`([A-Za-z0-9_./-]+\.md)`');
    final bare = RegExp(r'[A-Za-z0-9_./-]+\.md');
    final refs = <(Uri, String, Uri?)>[];
    for (final doc in docs) {
      for (final m in backticked.allMatches(File.fromUri(doc).readAsStringSync())) {
        final ref = m.group(1)!;
        if (!leavesRepo(ref, doc)) refs.add((doc, ref, doc));
      }
    }
    for (final src in testSources) {
      for (final m in bare.allMatches(File.fromUri(src).readAsStringSync())) {
        final ref = m.group(0)!;
        if (!ref.startsWith('../')) refs.add((src, ref, null));
      }
    }
    expect(refs, isNotEmpty,
        reason: '문서 경로를 하나도 찾지 못하면 아무것도 보지 않고 통과한다 — CLAUDE.md');

    final missing = refs
        .where((r) => resolveDoc(r.$2, r.$3) == null)
        .map((r) => '${rel(r.$1)} → ${r.$2}')
        .toList();
    expect(missing, isEmpty,
        reason: '문서를 옮기거나 지우면 이름을 적은 곳도 함께 고친다 — CLAUDE.md');
  });

  test('인용한 절이 그 문서에 있다', () {
    final problems = <String>[];
    var examined = 0;

    void verify(String at, String ref, Uri? target, String section) {
      examined++;
      if (target == null) {
        problems.add('$at → $ref 가 없다');
      } else if (!cites(target, section)) {
        problems.add('$at → $ref 에 "$section" 절이 없다');
      }
    }

    for (final doc in docs) {
      final lines = linesOf(doc);
      for (var i = 0; i < lines.length; i++) {
        final at = '${rel(doc)}:${i + 1}';
        for (final m in docCitation.allMatches(lines[i])) {
          final ref = m.group(1)!;
          if (!leavesRepo(ref, doc)) verify(at, ref, resolveDoc(ref, doc), cited(m, 2));
        }
        // 서버 저장소의 절을 인용한 것은 그 저장소가 여기 없으므로 검사하지 않는다
        if (!lines[i].contains('서버 저장소')) {
          for (final m in readmeCitation.allMatches(lines[i])) {
            verify(at, 'README.md', readme, cited(m, 1));
          }
        }
        for (final m in localCitation.allMatches(lines[i])) {
          verify(at, rel(doc), doc, cited(m, 1));
        }
      }
    }
    for (final src in testSources) {
      final lines = linesOf(src);
      for (var i = 0; i < lines.length; i++) {
        for (final m in docCitation.allMatches(lines[i])) {
          final ref = m.group(1)!;
          verify('${rel(src)}:${i + 1}', ref, resolveDoc(ref), cited(m, 2));
        }
      }
    }
    expect(examined, greaterThan(0),
        reason: '인용을 하나도 찾지 못하면 아무것도 보지 않고 통과한다. 인용 형식이 바뀌었을 수 있다 — CLAUDE.md');
    expect(problems, isEmpty,
        reason: '절 이름을 바꾸면 인용한 곳도 함께 고친다 — CLAUDE.md');
  });

  test('계약 절은 스스로 계약임을 밝힌다', () {
    // 앱은 계약을 제공하지 않고 서버의 계약을 따르므로, 계약 절이 없을 수 있다.
    final unmarked = <String>[];
    for (final doc in docs) {
      final lines = linesOf(doc);
      final headings = headingsOf(lines);
      for (final h in headings.where((h) => h.$3.contains('계약'))) {
        final section = lines.sublist(h.$1, sectionEnd(lines, headings, h));
        if (!section.any((l) => l.contains('이 절은 계약이다'))) {
          unmarked.add('${rel(doc)} → ${h.$3}');
        }
      }
    }
    expect(unmarked, isEmpty,
        reason: '표식이 없으면 코드를 뒤따르는 설명으로 읽혀, '
            '어긋났을 때 코드가 아니라 문서를 고치게 된다 — CLAUDE.md');
  });

  test('스스로 문서임을 밝힌 문서는 문서 지도에 있다', () {
    final mapped = mappedDocs();
    expect(mapped, isNotNull, reason: 'README.md 에 문서 지도 절이 없다 — CLAUDE.md');
    final declared = docs
        .where((d) => d != readme)
        .where((d) => linesOf(d).take(15).any((l) => l.startsWith('> **범위**')))
        .toList();
    expect(declared, isNotEmpty,
        reason: '머리글로 문서임을 밝힌 모듈 문서를 하나도 찾지 못하면 문서 지도 검사가 아무것도 보지 않는다 — CLAUDE.md');

    final unmapped = declared.where((d) => !mapped!.contains(d)).map(rel).toList();
    expect(unmapped, isEmpty,
        reason: '문서를 만들면 문서 지도에 올린다. 찾아갈 길이 없는 문서는 읽히지 않는다 — CLAUDE.md');
  });

  test('머리글이 범위와 책임을 밝힌다', () {
    final problems = <String>[];
    for (final doc in [readme, ...?mappedDocs()]) {
      if (!isFile(doc)) continue;
      final head = linesOf(doc).take(15).where((l) => l.startsWith('>')).join(' ');
      final labels = ['범위', '여기 없는 것', if (doc != readme) '상위'];
      for (final label in labels) {
        if (!head.contains('**$label**')) problems.add('${rel(doc)} → $label');
      }
    }
    expect(problems, isEmpty,
        reason: '머리글이 어디까지 믿고 어디부터 코드를 볼지 알려준다 — CLAUDE.md');
  });

  test('제약 테스트는 실패 메시지에 근거 문서를 담는다', () {
    final others = constraintTests
        .where((u) => !u.path.endsWith('/document_constraint_test.dart'))
        .toList();
    expect(others, isNotEmpty,
        reason: '이 파일 말고 제약 테스트를 찾지 못하면 근거 문서 검사가 아무것도 보지 않고 통과한다 — CLAUDE.md');

    final site = RegExp(r'\bexpect\(');
    final problems = <String>[];
    var sites = 0;
    for (final file in constraintTests) {
      final source = File.fromUri(file).readAsStringSync();
      for (final m in site.allMatches(source)) {
        sites++;
        final end = source.indexOf(');', m.start);
        final call = source.substring(m.start, end < 0 ? source.length : end);
        if (!call.contains('.md')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          problems.add('${rel(file)}:$line');
        }
      }
    }
    expect(sites, greaterThan(0),
        reason: '검사 지점을 하나도 찾지 못하면 아무것도 보지 않고 통과한다. 검사 방식이 바뀌었을 수 있다 — CLAUDE.md');
    expect(problems, isEmpty,
        reason: '어긴 순간에 문서가 도착해야 한다. 주석이 아니라 실패 메시지에 적는다 — CLAUDE.md');
  });
}
