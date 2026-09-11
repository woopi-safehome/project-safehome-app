import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_safehome_app/core/services/api_client.dart';

/// 서버와 맞닿는 계층의 동작을 고정한다.
///
/// 화면 테스트는 이 계층을 지나가지 않고, 서버 계약 문서도 여기까지는 말해 주지
/// 않는다. 잘못 읽어도 화면에 빈 값이 보일 뿐 아무 에러가 나지 않는다.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  /// 청크를 순서대로 흘려보내는 스트리밍 응답을 만든다.
  http.Client streamingWith(List<String> chunks, {int status = 200}) {
    return MockClient.streaming((request, bodyStream) async {
      final controller = StreamController<List<int>>();
      for (final c in chunks) {
        controller.add(utf8.encode(c));
      }
      unawaited(controller.close());
      return http.StreamedResponse(controller.stream, status);
    });
  }

  group('진행 상황 구독', () {
    test('한 이벤트가 두 조각으로 끊겨 와도 잃지 않는다', () async {
      // 전용 라이브러리가 없어 직접 파싱한다. 남은 조각을 다음 조각으로
      // 이월하지 않으면 간헐적으로 이벤트를 잃는다.
      final client = ApiClient(
        client: streamingWith([
          'data: {"jobId":"j1","status":"IN_PRO',
          'GRESS","step":"PDF_PARSING","message":"파싱","timestamp":"2026-01-01T00:00:00"}\n',
        ]),
      );

      final events = await client.streamJobEvents('j1').toList();

      expect(events.length, 1);
      expect(events.first.message, '파싱');
    });

    test('한 조각에 여러 이벤트가 들어와도 모두 읽는다', () async {
      String ev(String msg) =>
          'data: {"jobId":"j1","status":"IN_PROGRESS","step":"PDF_PARSING",'
          '"message":"$msg","timestamp":"2026-01-01T00:00:00"}\n';

      final client = ApiClient(client: streamingWith([ev('하나') + ev('둘'), ev('셋')]));

      final events = await client.streamJobEvents('j1').toList();

      expect(events.map((e) => e.message).toList(), ['하나', '둘', '셋']);
    });

    test('data 가 아닌 줄은 건너뛴다', () async {
      final client = ApiClient(
        client: streamingWith([
          ': keep-alive\n\n',
          'data: {"jobId":"j1","status":"COMPLETED","step":null,'
              '"message":"완료","timestamp":"2026-01-01T00:00:00"}\n',
        ]),
      );

      final events = await client.streamJobEvents('j1').toList();

      expect(events.length, 1);
      expect(events.first.message, '완료');
    });
  });

  group('작업 조회', () {
    test('결과가 문자열로 와도 객체로 읽는다', () async {
      // 서버는 JSON 객체를 그대로 내려주지만 문자열로 감싸여 오는 경우가 있다.
      // 한 번 더 풀지 않으면 결과 화면이 통째로 비어 보인다.
      final body = jsonEncode({
        'type': 'success',
        'data': {
          'jobId': 'j1',
          'fileName': 'a.pdf',
          'fileSize': 1,
          'status': 'COMPLETED',
          'step': null,
          'description': null,
          'result': jsonEncode({'isValidDeed': true, 'safetyLevel': 'DANGER'}),
        },
      });

      final client = ApiClient(
        client: MockClient((r) async => http.Response(body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );

      final job = await client.getJob('j1');

      expect(job.result, isNotNull);
      expect(job.result!.isValidDeed, isTrue);
    });
  });

  group('디바이스 등록', () {
    test('서버가 실패해도 예외를 올리지 않는다', () async {
      // 알림은 부가 기능이다. 등록 실패로 앱 시작을 막을 이유가 없다.
      final client = ApiClient(
        client: MockClient((r) async => throw const SocketException('network down')),
      );

      await client.registerDevice('fcm-token');
    });
  });

  group('인증 헤더', () {
    test('토큰이 없으면 헤더 없이 나간다', () async {
      // 예외가 아니다. 서버가 거절하고 클라이언트에서는 그냥 실패로 보인다.
      String? authHeader = 'not-called';
      final client = ApiClient(
        client: MockClient((r) async {
          authHeader = r.headers['Authorization'];
          return http.Response('boom', 500);
        }),
      );

      await client.registerDevice('fcm-token');

      expect(authHeader, isNull);
    });
  });
}
