import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../models/deed.dart';
import '../errors/app_exceptions.dart';
import 'logger.dart';
import 'token_storage.dart';

const String _tag = 'ApiClient';

// --dart-define=API_URL=http://... 로 주입 가능
const String _envApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

String get _baseUrl {
  if (_envApiUrl.isNotEmpty) return _envApiUrl;
  return 'http://devupii.store:38080';
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// PDF 업로드 → SSE 스트림에서 jobId 추출
  Future<String> uploadDeed(
    String filePath,
    String fileName,
    String mimeType, {
    String? leaseType,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/deed/analyze');
    AppLogger.info(_tag, 'uploadDeed start', context: {'uri': uri.toString()});

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers.addAll(await _authHeaders());

    if (leaseType != null) {
      request.fields['leaseType'] = leaseType;
    }

    try {
      final parts = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
          contentType: MediaType(parts[0], parts.length > 1 ? parts[1] : 'pdf'),
        ),
      );
    } catch (e) {
      throw NetworkException('파일을 읽을 수 없습니다.', uri.toString(), cause: e);
    }

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e) {
      throw NetworkException('서버에 연결할 수 없습니다.', uri.toString(), cause: e);
    }

    if (streamed.statusCode != 200) {
      throw ApiException(
        'HTTP ${streamed.statusCode}',
        streamed.statusCode,
        uri.toString(),
      );
    }

    String? jobId;
    final buffer = StringBuffer();

    try {
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final lines = buffer.toString().split('\n');
        // 마지막 불완전 줄은 버퍼에 남김
        buffer
          ..clear()
          ..write(lines.last);

        for (final line in lines.sublist(0, lines.length - 1)) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;

          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty) continue;

          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final event = SseEvent.fromJson(map);
            jobId ??= event.jobId;
            AppLogger.info(_tag, 'SSE event', context: {'status': event.status.name});
          } catch (e) {
            throw ParseException('SSE 파싱 실패: $e');
          }
        }

        if (jobId != null) break;
      }
    } catch (e) {
      if (e is ParseException) rethrow;
      throw NetworkException('스트림 읽기 실패', uri.toString(), cause: e);
    }

    if (jobId == null) {
      throw ParseException('jobId를 받지 못했습니다.');
    }

    AppLogger.info(_tag, 'uploadDeed done', context: {'jobId': jobId});
    return jobId;
  }

  /// 작업 SSE 스트림 구독
  Stream<SseEvent> streamJobEvents(String jobId) async* {
    final uri = Uri.parse('$_baseUrl/api/deed/jobs/$jobId/stream');
    AppLogger.info(_tag, 'streamJobEvents start', context: {'jobId': jobId});

    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers.addAll(await _authHeaders());

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e) {
      throw NetworkException('서버에 연결할 수 없습니다.', uri.toString(), cause: e);
    }

    if (streamed.statusCode != 200) {
      throw ApiException(
        'HTTP ${streamed.statusCode}',
        streamed.statusCode,
        uri.toString(),
        jobId: jobId,
      );
    }

    final buffer = StringBuffer();
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n');
      buffer
        ..clear()
        ..write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final jsonStr = trimmed.substring(5).trim();
        if (jsonStr.isEmpty) continue;

        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          yield SseEvent.fromJson(map);
        } catch (e) {
          throw ParseException('SSE 파싱 실패: $e', jobId: jobId);
        }
      }
    }
  }

  /// 작업 상태 조회
  Future<DeedJob> getJob(String jobId) async {
    final uri = Uri.parse('$_baseUrl/api/deed/jobs/$jobId');

    final http.Response response;
    try {
      response = await _client.get(uri, headers: await _authHeaders());
    } catch (e) {
      throw NetworkException('서버에 연결할 수 없습니다.', uri.toString(), cause: e);
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'HTTP ${response.statusCode}',
        response.statusCode,
        uri.toString(),
        jobId: jobId,
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // data.result 필드가 @JsonRawValue 로 문자열로 올 경우 처리
      final data = json['data'] as Map<String, dynamic>;
      if (data['result'] is String) {
        data['result'] = jsonDecode(data['result'] as String);
      }
      return DeedJob.fromJson(data);
    } catch (e) {
      throw ParseException('응답 파싱 실패: $e', jobId: jobId);
    }
  }

  /// 내 분석 이력 목록 조회
  Future<DeedJobsPage> getMyJobs({int page = 0, int size = 20}) async {
    final uri = Uri.parse('$_baseUrl/api/deed/jobs').replace(
      queryParameters: {'page': '$page', 'size': '$size'},
    );

    final http.Response response;
    try {
      response = await _client.get(uri, headers: await _authHeaders());
    } catch (e) {
      throw NetworkException('서버에 연결할 수 없습니다.', uri.toString(), cause: e);
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'HTTP ${response.statusCode}',
        response.statusCode,
        uri.toString(),
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final itemsJson = data['items'] as List<dynamic>;
      final pagination = data['pagination'] as Map<String, dynamic>;

      return DeedJobsPage(
        items: itemsJson
            .map((e) => DeedJobSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasNext: pagination['hasNext'] as bool,
        totalElements: (pagination['totalElements'] as num).toInt(),
      );
    } catch (e) {
      throw ParseException('응답 파싱 실패: $e');
    }
  }
}
