import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_safehome_app/core/errors/app_exceptions.dart';
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

  group('실패 응답', () {
    /// 서버가 봉투에 담아 보내는 실패 형태.
    String envelope(String code, String message) =>
        jsonEncode({'type': 'error', 'code': code, 'message': message, 'details': null});

    test('업로드가 거절되면 판별 코드와 서버 문구를 들고 온다', () async {
      // 상태 코드만 들고 가면 화면이 전부 "서버 오류"로 보여 준다.
      // 업로드는 스트리밍 응답이라 본문을 따로 읽어야 한다 — 빼먹기 쉬운 곳이다.
      final file = File('${Directory.systemTemp.path}/deed.pdf')..writeAsBytesSync([1, 2]);
      final client = ApiClient(
        client: MockClient.streaming((request, bodyStream) async {
          final body = utf8.encode(
            envelope('DAILY_LIMIT_EXCEEDED', '오늘 분석 가능한 횟수를 모두 사용했습니다.'),
          );
          return http.StreamedResponse(Stream.value(body), 429);
        }),
      );

      final error = await client
          .uploadDeed(file.path, 'deed.pdf', 'application/pdf')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ApiException>());
      expect((error as ApiException).code, ApiErrorCode.dailyLimitExceeded);
      expect(error.message, '오늘 분석 가능한 횟수를 모두 사용했습니다.');
      expect(error.statusCode, 429);
    });

    test('모르는 코드가 와도 깨지지 않는다', () async {
      // 서버가 앱보다 먼저 배포된다. 새 코드가 와도 동작해야 한다.
      final client = ApiClient(
        client: MockClient((r) async => http.Response(
              envelope('SOMETHING_NEW', '새 코드입니다.'),
              418,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );

      final error = await client
          .getJob('j1')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect((error as ApiException).code, ApiErrorCode.unknown);
      expect(error.message, '새 코드입니다.');
    });

    test('봉투가 아닌 응답은 본문을 믿지 않는다', () async {
      // 프록시가 가로챈 HTML 이나 장애 페이지가 이 경우다.
      final client = ApiClient(
        client: MockClient((r) async => http.Response('<html>502</html>', 502)),
      );

      final error = await client
          .getJob('j1')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect((error as ApiException).code, ApiErrorCode.unknown);
      expect(error.message, 'HTTP 502');
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
