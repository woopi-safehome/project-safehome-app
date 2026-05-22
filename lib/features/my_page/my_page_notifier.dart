import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';

const _tag = 'MyPageNotifier';

// ─── State ────────────────────────────────────────────────────────────────────

class MyPageState {
  final List<DeedJobSummary> jobs;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasNext;
  final String? errorMessage;

  const MyPageState({
    this.jobs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasNext = false,
    this.errorMessage,
  });

  MyPageState copyWith({
    List<DeedJobSummary>? jobs,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasNext,
    Object? errorMessage = _sentinel,
  }) {
    return MyPageState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNext: hasNext ?? this.hasNext,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MyPageNotifier extends AutoDisposeNotifier<MyPageState> {
  int _currentPage = 0;

  @override
  MyPageState build() {
    return const MyPageState();
  }

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    _currentPage = 0;

    try {
      final apiClient = ref.read(apiClientProvider);
      final page = await apiClient.getMyJobs(page: 0);
      state = state.copyWith(
        jobs: page.items,
        hasNext: page.hasNext,
        isLoading: false,
      );
      AppLogger.info(_tag, 'load done', context: {'count': page.items.length});
    } on NetworkException catch (e) {
      AppLogger.error(_tag, 'network error', error: e);
      state = state.copyWith(isLoading: false, errorMessage: '네트워크 연결을 확인하세요.');
    } on ApiException catch (e) {
      AppLogger.error(_tag, 'api error', error: e);
      state = state.copyWith(isLoading: false, errorMessage: '분석 이력을 불러올 수 없습니다.');
    } catch (e) {
      AppLogger.error(_tag, 'unexpected error', error: e);
      state = state.copyWith(isLoading: false, errorMessage: '알 수 없는 오류가 발생했습니다.');
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNext || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final nextPage = _currentPage + 1;
      final page = await apiClient.getMyJobs(page: nextPage);
      _currentPage = nextPage;
      state = state.copyWith(
        jobs: [...state.jobs, ...page.items],
        hasNext: page.hasNext,
        isLoadingMore: false,
      );
    } catch (e) {
      AppLogger.error(_tag, 'loadMore error', error: e);
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final myPageNotifierProvider =
    AutoDisposeNotifierProvider<MyPageNotifier, MyPageState>(
  MyPageNotifier.new,
);
