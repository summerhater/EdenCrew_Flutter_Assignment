import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../watchlist/data/providers/watchlist_repository_provider.dart';
import '../../../watchlist/domain/models/watchlist_models.dart';
import '../../../watchlist/domain/repositories/watchlist_repository.dart';
import '../../../watchlist/presentation/providers/favorite_ids_controller.dart';

final searchControllerProvider =
    NotifierProvider<SearchController, SearchUiState>(SearchController.new);

class SearchController extends Notifier<SearchUiState> {
  WatchlistRepository get _repository => ref.read(watchlistRepositoryProvider);

  Timer? _toastTimer;
  int _requestSequence = 0;

  @override
  SearchUiState build() {
    ref.onDispose(() => _toastTimer?.cancel());
    // TODO(assignment): favoriteIdsControllerProvider를 listen해서
    // 즐겨찾기 상태가 바뀔 때마다 현재 검색 결과의 isFavorite를 다시 매핑하세요.
    // 관련 테스트:
    // - test/features/search/presentation/providers/search_controller_test.dart

    // ref.watch 대신 ref.listen 사용 — watch는 build 전체를 재실행하므로
    // 검색 상태가 초기화될 수 있음. listen은 콜백만 호출하므로 결과만 갱신 가능
    ref.listen<AsyncValue<Set<String>>>(
      favoriteIdsControllerProvider,
      (previous, next) => _applyFavoriteIds(next.valueOrNull),
    );
    return const SearchUiState();
  }

  Future<void> setQuery(String query) async {
    _requestSequence += 1;
    final currentRequestId = _requestSequence;
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      _toastTimer?.cancel();
      state = state.copyWith(
        query: query,
        results: const AsyncData(<StockSearchItem>[]),
        selectedItemId: null,
        toast: null,
      );
      return;
    }

    final existingResults = state.results;
    final loadingResults = existingResults.hasValue
        ? const AsyncLoading<List<StockSearchItem>>().copyWithPrevious(
            existingResults,
          )
        : const AsyncLoading<List<StockSearchItem>>();

    state = state.copyWith(
      query: query,
      results: loadingResults,
      selectedItemId: null,
      toast: null,
    );

    final result = await AsyncValue.guard(
      () => _repository.searchStocks(query: trimmedQuery),
    );
    if (currentRequestId != _requestSequence) {
      return;
    }

    // TODO(assignment): favoriteIdsControllerProvider의 현재 값을 읽어서
    // 첫 검색 결과에도 isFavorite가 반영되도록 연결하세요.
    // 관련 테스트:
    // - test/features/search/presentation/providers/search_controller_test.dart

    // 검색 결과 수신 직후 provider의 현재 값으로 isFavorite를 동기화
    // - ref.listen은 이후 변경만 감지 -> 최초 결과에는 수동 적용 필요
    final currentFavoriteIds =
        ref.read(favoriteIdsControllerProvider).valueOrNull;
    state = state.copyWith(
      results: result.whenData(
        (items) => currentFavoriteIds == null
            ? items
            : items
                  .map(
                    (item) => item.copyWith(
                      isFavorite: currentFavoriteIds.contains(item.id),
                    ),
                  )
                  .toList(growable: false),
      ),
      selectedItemId: null,
    );
  }

  void clearQuery() {
    _requestSequence += 1;
    _toastTimer?.cancel();
    state = state.copyWith(
      query: '',
      results: const AsyncData(<StockSearchItem>[]),
      selectedItemId: null,
      toast: null,
    );
  }

  void setFocused(bool isFocused) {
    if (state.isFocused == isFocused) {
      return;
    }
    state = state.copyWith(isFocused: isFocused);
  }

  void toggleSelection(StockSearchItem item) {
    state = state.copyWith(
      selectedItemId: state.selectedItemId == item.id ? null : item.id,
    );
  }

  void clearSelection() {
    if (state.selectedItemId == null) {
      return;
    }
    state = state.copyWith(selectedItemId: null);
  }

  Future<bool> toggleFavorite(StockSearchItem item) async {
    final isAdded = await ref
        .read(favoriteIdsControllerProvider.notifier)
        .toggle(item.id);

    // TODO(assignment): toggle 이후 최신 favorite 상태를 현재 검색 결과에 다시
    // 반영하고, 추가 시 토스트를 보여주고 제거 시 토스트를 닫으세요.
    // 관련 테스트:
    // - test/features/search/presentation/providers/search_controller_test.dart

    // toggle 완료 후 provider의 최신 상태로 결과 갱신
    // — toggle이 비동기이므로 완료 시점의 valueOrNull을 읽어야 정확한 상태 반영
    _applyFavoriteIds(ref.read(favoriteIdsControllerProvider).valueOrNull);

    if (isAdded) {
      _showToast(const SearchToastData(message: '관심그룹에 추가되었습니다.'));
    } else {
      dismissToast();
    }

    return isAdded;
  }

  void dismissToast() {
    _toastTimer?.cancel();
    if (state.toast == null) {
      return;
    }
    state = state.copyWith(toast: null);
  }
  
  void _showToast(SearchToastData toast) {
    _toastTimer?.cancel();
    state = state.copyWith(toast: toast);
    _toastTimer = Timer(const Duration(seconds: 2), dismissToast);
  }
  
  void _applyFavoriteIds(Set<String>? favoriteIds) {
    // TODO(assignment): favoriteIds에 맞게 현재 results의 isFavorite를 다시 매핑하세요.
    // selected item이 사라진 경우 selectedItemId도 정리해 주세요.
    // 관련 테스트:
    // - test/features/search/presentation/providers/search_controller_test.dart
    if (favoriteIds == null) {
      return;
    }
    // results에 값이 없으면 매핑 대상 x -> 조기 반환
    if (!state.results.hasValue) return;

    final updatedItems = state.results.requireValue
        .map((item) => item.copyWith(isFavorite: favoriteIds.contains(item.id)))
        .toList(growable: false);

    // 즐겨찾기 변경으로 선택된 아이템이 사라진 경우 selectedItemId 해제
    final selectedStillPresent = updatedItems.any(
      (item) => item.id == state.selectedItemId,
    );
    state = state.copyWith(
      results: AsyncData(updatedItems),
      selectedItemId: selectedStillPresent ? state.selectedItemId : null,
    );
  }
}

@immutable
class SearchUiState {
  const SearchUiState({
    this.query = '',
    this.results = const AsyncData(<StockSearchItem>[]),
    this.selectedItemId,
    this.isFocused = false,
    this.toast,
  });

  final String query;
  final AsyncValue<List<StockSearchItem>> results;
  final String? selectedItemId;
  final bool isFocused;
  final SearchToastData? toast;

  SearchUiState copyWith({
    String? query,
    AsyncValue<List<StockSearchItem>>? results,
    Object? selectedItemId = _sentinel,
    bool? isFocused,
    Object? toast = _sentinel,
  }) {
    return SearchUiState(
      query: query ?? this.query,
      results: results ?? this.results,
      selectedItemId: selectedItemId == _sentinel
          ? this.selectedItemId
          : selectedItemId as String?,
      isFocused: isFocused ?? this.isFocused,
      toast: toast == _sentinel ? this.toast : toast as SearchToastData?,
    );
  }
}

@immutable
class SearchToastData {
  const SearchToastData({required this.message});

  final String message;
}

const _sentinel = Object();
