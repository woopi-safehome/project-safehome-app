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
      state = state.copyWith(uploading: false, errorMessage: '서버 오류가 발생했습니다. (${ e.statusCode})');
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
