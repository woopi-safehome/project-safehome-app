import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/logger.dart';

const _tag = 'UploadNotifier';

// ─── State ────────────────────────────────────────────────────────────────────

class UploadState {
  final PlatformFile? selectedFile;
  final String? leaseType; // '전세' | '월세' | null
  final bool uploading;
  final String? errorMessage;

  const UploadState({
    this.selectedFile,
    this.leaseType,
    this.uploading = false,
    this.errorMessage,
  });

  UploadState copyWith({
    PlatformFile? selectedFile,
    Object? leaseType = _sentinel,
    bool? uploading,
    Object? errorMessage = _sentinel,
  }) {
    return UploadState(
      selectedFile: selectedFile ?? this.selectedFile,
      leaseType: leaseType == _sentinel ? this.leaseType : leaseType as String?,
      uploading: uploading ?? this.uploading,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// 서버가 거절한 이유를 사용자에게 보일 문구로 바꾼다.
///
/// **하루 제한은 다시 눌러도 같다.** 그래서 서버 문구에 언제 풀리는지를 덧붙인다 —
/// 알려 주지 않으면 사용자는 계속 누른다.
///
/// **파일이 너무 큰 것도 사용자가 할 일이 있는 경우다.** 기본 분기로 떨어뜨리면
/// "서버 오류가 발생했습니다. (413)" 가 나가, 고칠 수 있는 일을 서버 잘못처럼 보이게 한다.
///
/// 그 밖의 실패는 상태 코드를 보여 준다. 사용자가 할 수 있는 일이 없고 문의에 쓰인다.
String _messageOf(ApiException e) => switch (e.code) {
      ApiErrorCode.dailyLimitExceeded => '${e.message}\n내일 다시 분석할 수 있습니다.',
      ApiErrorCode.fileTooLarge => '${e.message}\n더 작은 파일로 다시 시도해 주세요.',
      _ => '서버 오류가 발생했습니다. (${e.statusCode})',
    };

class UploadNotifier extends AutoDisposeNotifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    state = state.copyWith(selectedFile: result.files.first, errorMessage: null);
  }

  void toggleLeaseType(String type) {
    final next = state.leaseType == type ? null : type;
    state = state.copyWith(leaseType: next);
  }

  /// 업로드를 수행하고 성공 시 jobId를 반환한다.
  Future<String?> upload() async {
    final file = state.selectedFile;
    if (file == null || file.path == null) return null;

    final apiClient = ref.read(apiClientProvider);

    state = state.copyWith(uploading: true, errorMessage: null);
    AppLogger.info(_tag, 'upload start', context: {'file': file.name});

    try {
      final jobId = await apiClient.uploadDeed(
        file.path!,
        file.name,
        'application/pdf',
        leaseType: state.leaseType,
      );
      AppLogger.info(_tag, 'upload success', context: {'jobId': jobId});
      return jobId;
    } on NetworkException catch (e) {
      AppLogger.error(_tag, 'network error', error: e);
      state = state.copyWith(uploading: false, errorMessage: '네트워크 연결을 확인하세요.');
      return null;
    } on ApiException catch (e) {
      AppLogger.error(_tag, 'api error', error: e);
      state = state.copyWith(uploading: false, errorMessage: _messageOf(e));
      return null;
    } catch (e) {
      AppLogger.error(_tag, 'unexpected error', error: e);
      state = state.copyWith(uploading: false, errorMessage: '알 수 없는 오류가 발생했습니다.');
      return null;
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final uploadNotifierProvider = AutoDisposeNotifierProvider<UploadNotifier, UploadState>(
  UploadNotifier.new,
);
