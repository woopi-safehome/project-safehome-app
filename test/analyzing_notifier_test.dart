import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_safehome_app/core/services/api_client.dart';
import 'package:project_safehome_app/features/analyzing/analyzing_notifier.dart';

/// 분석 진행 화면이 끝나는 경우들을 고정한다.
///
/// 끝나는 길이 셋이다 — 정상 완료, 실패 이벤트, 스트림의 비정상 종료.
/// 세 번째를 빼먹으면 연결이 끊겼을 때 화면이 영원히 진행 중으로 남는다.
///
/// 배경: lib/features/README.md 의 "끝나는 경우가 셋이다"
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  String event(String status, {String? step, String message = '진행'}) => 'data: '
      '${jsonEncode({
            'jobId': 'j1',
            'status': status,
            'step': step,
            'message': message,
            'timestamp': '2026-01-01T00:00:00',
          })}\n';

  /// 구독은 주어진 조각을 흘린 뒤 닫히고, 결과 조회는 주어진 본문을 돌려준다.
  ApiClient clientWith({required List<String> stream, String? jobBody}) {
    return ApiClient(
      client: MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('/stream')) {
          final controller = StreamController<List<int>>();
          for (final c in stream) {
            controller.add(utf8.encode(c));
          }
          unawaited(controller.close());
          return http.StreamedResponse(controller.stream, 200);
        }
        final body = jobBody ?? '{}';
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          jobBody == null ? 500 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  Future<AnalyzingState> runUntilSettled(ApiClient client) async {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    // 프로바이더를 읽는 것만으로 구독이 시작된다
    container.read(analyzingNotifierProvider('j1'));
    // 스트림이 닫히고 뒤따르는 비동기 처리가 끝날 때까지 흘려보낸다
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(analyzingNotifierProvider('j1'));
  }

  test('스트림이 완료 없이 끊기면 오류로 알린다', () async {
    // 이 경로가 없으면 화면이 영원히 진행 중으로 남는다.
    final state = await runUntilSettled(
      clientWith(stream: [event('IN_PROGRESS', step: 'PDF_PARSING')]),
    );

    expect(state.errorMessage, isNotNull);
  });

  test('실패 이벤트를 받으면 진행 중으로 남지 않는다', () async {
    final state = await runUntilSettled(
      clientWith(stream: [event('FAILED', message: '검증 실패')]),
    );

    // 실패는 스트림 종료로 인한 오류와 구분된다 — 서버가 사유를 준다.
    expect(state.errorMessage, isNull);
  });

  test('완료를 받으면 결과를 따로 조회한다', () async {
    // 완료 이벤트는 결과를 담고 있지 않다. 이 두 단계를 하나로 착각하면
    // 결과가 비어 보인다.
    final jobBody = jsonEncode({
      'type': 'success',
      'data': {
        'jobId': 'j1',
        'fileName': 'a.pdf',
        'fileSize': 1,
        'status': 'COMPLETED',
        'step': null,
        'description': null,
        'result': {'isValidDeed': true, 'safetyLevel': 'SAFE'},
      },
    });

    final state = await runUntilSettled(
      clientWith(
        stream: [event('COMPLETED', step: 'POST_PROCESSING', message: '완료')],
        jobBody: jobBody,
      ),
    );

    expect(state.job, isNotNull);
    expect(state.job!.result!.isValidDeed, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('완료 뒤 결과 조회가 실패하면 오류로 알린다', () async {
    final state = await runUntilSettled(
      clientWith(stream: [event('COMPLETED', step: 'POST_PROCESSING', message: '완료')]),
    );

    expect(state.errorMessage, isNotNull);
    expect(state.job, isNull);
  });
}
