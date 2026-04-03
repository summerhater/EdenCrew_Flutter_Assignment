// ignore_for_file: unused_element, unused_field

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/watchlist_models.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../../domain/services/watchlist_sorting.dart';
import '../clients/naver_domestic_stock_client.dart';
import '../clients/naver_stock_logo_url_resolver.dart';
import '../dtos/naver_stock_dtos.dart';
import 'favorite_ids_local_store.dart';

class NaverWatchlistRepository implements WatchlistRepository {
  NaverWatchlistRepository({
    required Dio dio,
    required FavoriteIdsLocalStore favoriteIdsLocalStore,
    NaverStockDataClient? client,
    NaverStockLogoUrlResolver? logoUrlResolver,
    this.realtimeCacheTtl = const Duration(seconds: 10),
    this.dailyHistoryFetchBatchSize = 4,
  }) : _client = client ?? NaverDomesticStockClient(dio),
       _favoriteIdsLocalStore = favoriteIdsLocalStore,
       _logoUrlResolver = logoUrlResolver ?? const NaverStockLogoUrlResolver();

  static const _historyRowsPerPage = 10;

  final NaverStockDataClient _client;
  final FavoriteIdsLocalStore _favoriteIdsLocalStore;
  final NaverStockLogoUrlResolver _logoUrlResolver;
  final Duration realtimeCacheTtl;
  final int dailyHistoryFetchBatchSize;

  final Map<String, NaverChartMetadataDto> _metadataCache = {};
  final Map<String, NaverDailyHistoryPageDto> _dailyHistoryPageCache = {};
  final Map<String, _RealtimeQuoteCacheEntry> _realtimeQuoteCache = {};

  Set<String>? _favoriteIdsCache;
  List<DateTime>? _availableDatesCache;

  @override
  Future<WatchlistSnapshot> fetchWatchlist({DateTime? asOf}) async {
    // TODO(assignment): Build the watchlist snapshot from Naver data.
    //
    // Suggested flow:
    // 1. Load canonical favorite ids via loadFavoriteIds().
    // 2. Convert each id into a six-digit domestic symbol.
    // 3. Load metadata and realtime quotes for those symbols.
    // 4. When asOf is null, use the latest historical row for each symbol.
    // 5. When asOf is provided, resolve the selected trading day and build a
    //    one-day snapshot for that date.
    // 6. Map every symbol into WatchlistItem.
    //
    // Related tests:
    // - test/features/watchlist/data/naver_watchlist_repository_test.dart
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.fetchWatchlist',
    // );

    final favoriteIds = await loadFavoriteIds();
    // Note(assignment): canonical id에서 6자리 symbol을 추출 — 타입 필터로 null 제거
    final symbols = favoriteIds
        .map((id) => domesticSymbolFromFavoriteId(id))
        .whereType<String>()
        .toList();

    if (symbols.isEmpty) {
      return WatchlistSnapshot(
        asOf: normalizeAsOfDate(asOf ?? DateTime.now()),
        items: [],
      );
    }

    final metadataBySymbol = await _loadMetadataBatch(symbols);
    final availableDates = await fetchAvailableDates();
    final resolvedAsOf = _resolveAsOf(availableDates, asOf);
    // Note(assignment): latestDate를 전달해 _buildWatchlistItem이 realtime 사용 여부를 판단하게 함
    final latestDate = availableDates.isNotEmpty ? availableDates.first : null;
    final realtimeQuotes = await _loadRealtimeQuotes(symbols);

    final items = <WatchlistItem>[];
    for (final symbol in symbols) {
      final metadata = metadataBySymbol[symbol];
      if (metadata == null) continue;

      final historicalEntry = await _loadHistoricalEntryForDate(
        symbol: symbol,
        availableDates: availableDates,
        asOf: resolvedAsOf,
      );
      if (historicalEntry == null) continue;

      items.add(
        _buildWatchlistItem(
          symbol: symbol,
          metadata: metadata,
          historicalEntry: historicalEntry,
          realtimeQuote: realtimeQuotes[symbol],
          latestDate: latestDate,
        ),
      );
    }

    return WatchlistSnapshot(
      asOf: resolvedAsOf,
      items: items,
      availableDates: availableDates,
    );
  }

  @override
  Future<List<DateTime>> fetchAvailableDates() async {
    // TODO(assignment): Lazily load and cache the trading-day list.
    //
    // Suggested flow:
    // - Reuse _availableDatesCache when present.
    // - Pick the first valid favorite symbol as the reference symbol.
    // - Request page 1 first to discover lastPage.
    // - Fetch the remaining pages in small batches.
    // - Flatten all localDate values into one descending list.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.fetchAvailableDates',
    // );

    if (_availableDatesCache != null) {
      return List.unmodifiable(_availableDatesCache!);
    }

    // Note(assignment): 첫 번째 유효한 favorite symbol을 기준 종목으로 선택
    final favoriteIds = await loadFavoriteIds();
    String? referenceSymbol;
    for (final id in favoriteIds) {
      final symbol = domesticSymbolFromFavoriteId(id);
      if (symbol != null) {
        referenceSymbol = symbol;
        break;
      }
    }

    if (referenceSymbol == null) {
      _availableDatesCache = [];
      return List.unmodifiable(_availableDatesCache!);
    }

    // Note(assignment): page 1을 먼저 요청해 lastPage를 확인한 뒤 나머지를 batch로 fetch
    final firstPage = await _loadDailyHistoryPage(referenceSymbol, 1);
    final lastPage = firstPage.lastPage;
    final allPages = [firstPage];

    for (
      var pageNum = 2;
      pageNum <= lastPage;
      pageNum += dailyHistoryFetchBatchSize
    ) {
      final batchEnd = (pageNum + dailyHistoryFetchBatchSize - 1).clamp(
        pageNum,
        lastPage,
      );
      final batch = await Future.wait([
        for (var p = pageNum; p <= batchEnd; p++)
          _loadDailyHistoryPage(referenceSymbol, p),
      ]);
      allPages.addAll(batch);
    }

    final allDates =
        allPages.expand((page) => page.priceInfos).map((row) => row.localDate).toList();
    // Note(assignment): UI와 _resolveAsOf가 최신 날짜를 .first로 접근하므로 내림차순 정렬
    allDates.sort((a, b) => b.compareTo(a));

    _availableDatesCache = allDates;
    return List.unmodifiable(_availableDatesCache!);
  }

  @override
  Future<WatchlistDetail> fetchWatchlistDetail({
    required String symbol,
    required MarketType market,
    DateTime? asOf,
  }) async {
    // TODO(assignment): Build the detail panel from a 30-trading-day window.
    //
    // Requirements:
    // - Only domestic stocks are supported.
    // - When asOf is null, show the latest available detail.
    // - When asOf is set, resolve the requested trading day and collect the
    //   previous 30 trading days (including the selected day).
    // - Use realtime data only for the latest trading day.
    // - Compute changeAmount, changeRate, volumeRatio, and candles.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.fetchWatchlistDetail',
    // );

    // Note(assignment): 해외 종목은 지원하지 않으므로 즉시 오류 throw
    if (market != MarketType.domestic) {
      throw UnsupportedError('Only domestic market is supported');
    }

    final availableDates = await fetchAvailableDates();
    final resolvedAsOf = _resolveAsOf(availableDates, asOf);
    final latestDate = availableDates.isNotEmpty ? availableDates.first : null;

    final historicalEntry = await _loadHistoricalEntryForDate(
      symbol: symbol,
      availableDates: availableDates,
      asOf: resolvedAsOf,
    );
    if (historicalEntry == null) {
      throw StateError('No historical data for $symbol on $resolvedAsOf');
    }

    // Note(assignment): selectedIndex 기준으로 최대 30개 거래일 윈도우를 구성
    final selectedIndex = _indexOfDate(availableDates, resolvedAsOf) ?? 0;
    final windowEndIndex = (selectedIndex + 30).clamp(0, availableDates.length);
    final windowDatesDescending = availableDates.sublist(
      selectedIndex,
      windowEndIndex,
    );

    // Note(assignment): 윈도우 내 페이지들을 로드하고 날짜 키 Map으로 변환
    final pageNumbers = windowDatesDescending
        .asMap()
        .entries
        .map((e) => _pageNumberForIndex(selectedIndex + e.key))
        .toSet();

    final rowsByDate = <String, NaverHistoricalPriceDto>{};
    for (final pageNum in pageNumbers) {
      final page = await _loadDailyHistoryPage(symbol, pageNum);
      for (final row in page.priceInfos) {
        rowsByDate[_dateKey(row.localDate)] = row;
      }
    }

    // Note(assignment): 최신 거래일에만 실시간 데이터를 사용 — 과거 날짜에 적용하면 시점 불일치 발생
    final isLatest = latestDate != null && resolvedAsOf == latestDate;
    NaverRealtimeQuoteDto? realtimeQuote;
    if (isLatest) {
      final quotes = await _loadRealtimeQuotes([symbol]);
      realtimeQuote = quotes[symbol];
    }

    final selectedRow = historicalEntry.row;
    final previousClose = historicalEntry.previousClose;

    final currentPrice = isLatest && realtimeQuote != null
        ? realtimeQuote.currentPrice
        : selectedRow.closePrice;
    final changeAmount = currentPrice - previousClose;
    final changeRate = isLatest && realtimeQuote != null
        ? realtimeQuote.changeRate
        : _percentChange(changeAmount, previousClose);
    final tradeVolume = isLatest && realtimeQuote != null
        ? realtimeQuote.accumulatedTradingVolume
        : selectedRow.accumulatedTradingVolume;

    return WatchlistDetail(
      itemId: canonicalDomesticFavoriteId(symbol),
      symbol: symbol,
      market: MarketType.domestic,
      currency: 'KRW',
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changeRate: changeRate,
      tradeVolume: tradeVolume,
      volumeRatio: _volumeRatio(
        windowDatesDescending: windowDatesDescending,
        rowsByDate: rowsByDate,
      ),
      openPrice: selectedRow.openPrice,
      openChangeRate: _percentChange(
        selectedRow.openPrice - previousClose,
        previousClose,
      ),
      highPrice: selectedRow.highPrice,
      highChangeRate: _percentChange(
        selectedRow.highPrice - previousClose,
        previousClose,
      ),
      lowPrice: selectedRow.lowPrice,
      lowChangeRate: _percentChange(
        selectedRow.lowPrice - previousClose,
        previousClose,
      ),
      candles: _candles(
        windowDatesDescending: windowDatesDescending,
        rowsByDate: rowsByDate,
      ),
    );
  }

  @override
  Future<List<StockSearchItem>> searchStocks({required String query}) async {
    // TODO(assignment): Search domestic stocks and convert them into
    // StockSearchItem values.
    //
    // Requirements:
    // - Trim the query and return [] for empty input.
    // - Use _client.searchStocks(trimmedQuery).
    // - Keep only domestic six-digit stock results.
    // - Deduplicate duplicate symbols.
    // - Convert every symbol into canonical id: domestic:{symbol}
    // - Set isFavorite by comparing against loadFavoriteIds().
    // - Fill logoUrl via _logoUrlResolver.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverWatchlistRepository.searchStocks',
    // );

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final favoriteIds = await loadFavoriteIds();
    final rawItems = await _client.searchStocks(trimmedQuery);

    // Note(assignment): 중복 symbol 제거 — Naver 자동완성이 같은 종목을 여러 번 반환할 수 있음
    final seenSymbols = <String>{};
    final results = <StockSearchItem>[];

    for (final item in rawItems) {
      if (!item.isDomesticStock) continue;
      if (!seenSymbols.add(item.code)) continue;

      final id = canonicalDomesticFavoriteId(item.code);
      results.add(
        StockSearchItem(
          id: id,
          market: MarketType.domestic,
          marketLabel: item.typeName,
          symbol: item.code,
          name: item.name,
          isFavorite: favoriteIds.contains(id),
          logoUrl: _logoUrlResolver.resolveDomesticStockLogoUrl(item.code),
        ),
      );
    }

    return results;
  }

  @override
  Future<Set<String>> loadFavoriteIds() async {
    if (_favoriteIdsCache != null) {
      return Set<String>.unmodifiable(_favoriteIdsCache!);
    }

    final rawIds = await _favoriteIdsLocalStore.loadRawIds();
    final canonicalIds = rawIds.where(_isCanonicalFavoriteId).toSet();
    final hasLegacyOrInvalidIds =
        rawIds.isNotEmpty && canonicalIds.length != rawIds.length;

    final resolvedIds = !_favoriteIdsLocalStore.hasStoredIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : hasLegacyOrInvalidIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : canonicalIds;

    _favoriteIdsCache = resolvedIds;

    if (!setEquals(rawIds, resolvedIds)) {
      await _favoriteIdsLocalStore.saveRawIds(resolvedIds);
    }

    return Set<String>.unmodifiable(resolvedIds);
  }

  @override
  Future<void> addFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds(), canonicalId};
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  @override
  Future<void> removeFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds()}..remove(canonicalId);
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  Future<Map<String, NaverChartMetadataDto>> _loadMetadataBatch(
    List<String> symbols,
  ) async {
    final results = <String, NaverChartMetadataDto>{};
    for (final symbol in symbols) {
      try {
        results[symbol] = await _loadMetadata(symbol);
      } catch (error, stackTrace) {
        debugPrint('Skipping Naver metadata for $symbol: $error\n$stackTrace');
      }
    }
    return results;
  }

  Future<NaverChartMetadataDto> _loadMetadata(String symbol) async {
    final cached = _metadataCache[symbol];
    if (cached != null) {
      return cached;
    }

    final metadata = await _client.fetchChartMetadata(symbol);
    _metadataCache[symbol] = metadata;
    return metadata;
  }

  Future<NaverDailyHistoryPageDto> _loadDailyHistoryPage(
    String symbol,
    int page,
  ) async {
    final cacheKey = _dailyHistoryPageCacheKey(symbol, page);
    final cached = _dailyHistoryPageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final historyPage = await _client.fetchDailyHistoryPage(
      symbol: symbol,
      page: page,
    );
    _dailyHistoryPageCache[cacheKey] = historyPage;
    return historyPage;
  }

  Future<Map<String, NaverRealtimeQuoteDto>> _loadRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    final requestedSymbols = symbols.toSet();
    final now = DateTime.now();
    final missingSymbols = <String>[];
    final quotes = <String, NaverRealtimeQuoteDto>{};

    for (final symbol in requestedSymbols) {
      final cached = _realtimeQuoteCache[symbol];
      final isFresh =
          cached != null &&
          now.difference(cached.fetchedAt) <= realtimeCacheTtl;
      if (isFresh) {
        quotes[symbol] = cached.quote;
      } else {
        missingSymbols.add(symbol);
      }
    }

    if (missingSymbols.isNotEmpty) {
      try {
        final fetchedQuotes = await _client.fetchRealtimeQuotes(missingSymbols);
        final fetchedAt = DateTime.now();
        for (final entry in fetchedQuotes.entries) {
          _realtimeQuoteCache[entry.key] = _RealtimeQuoteCacheEntry(
            quote: entry.value,
            fetchedAt: fetchedAt,
          );
          quotes[entry.key] = entry.value;
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Falling back to historical-only Naver data for realtime batch: '
          '$error\n$stackTrace',
        );
      }
    }

    return quotes;
  }

  Future<_HistoricalEntry?> _loadHistoricalEntryForDate({
    required String symbol,
    required List<DateTime> availableDates,
    required DateTime asOf,
  }) async {
    final selectedIndex = _indexOfDate(availableDates, asOf);
    if (selectedIndex == null) {
      return null;
    }

    final selectedPageNumber = _pageNumberForIndex(selectedIndex);
    final selectedPage = await _loadDailyHistoryPage(
      symbol,
      selectedPageNumber,
    );
    final selectedRow = _rowForDate(selectedPage.priceInfos, asOf);
    if (selectedRow == null) {
      return null;
    }

    final previousClose = await _resolvePreviousClose(
      symbol: symbol,
      availableDates: availableDates,
      selectedIndex: selectedIndex,
      fallbackOpenPrice: selectedRow.openPrice,
      rowsByDate: {
        for (final row in selectedPage.priceInfos) _dateKey(row.localDate): row,
      },
    );

    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  Future<_HistoricalEntry?> _loadLatestHistoricalEntry(String symbol) async {
    final firstPage = await _loadDailyHistoryPage(symbol, 1);
    if (firstPage.priceInfos.isEmpty) {
      return null;
    }

    final selectedRow = firstPage.priceInfos.first;
    double previousClose = selectedRow.openPrice;
    if (firstPage.priceInfos.length > 1) {
      previousClose = firstPage.priceInfos[1].closePrice;
    } else {
      final nextPageRows = (await _loadDailyHistoryPage(symbol, 2)).priceInfos;
      if (nextPageRows.isNotEmpty) {
        previousClose = nextPageRows.first.closePrice;
      }
    }

    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  Future<double> _resolvePreviousClose({
    required String symbol,
    required List<DateTime> availableDates,
    required int selectedIndex,
    required double fallbackOpenPrice,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) async {
    if (selectedIndex >= availableDates.length - 1) {
      return fallbackOpenPrice;
    }

    final previousDate = availableDates[selectedIndex + 1];
    final previousRowFromCache = rowsByDate[_dateKey(previousDate)];
    if (previousRowFromCache != null) {
      return previousRowFromCache.closePrice;
    }

    final page = await _loadDailyHistoryPage(
      symbol,
      _pageNumberForIndex(selectedIndex + 1),
    );
    final previousRow = _rowForDate(page.priceInfos, previousDate);
    return previousRow?.closePrice ?? fallbackOpenPrice;
  }

  WatchlistItem _buildWatchlistItem({
    required String symbol,
    required NaverChartMetadataDto metadata,
    required _HistoricalEntry historicalEntry,
    required NaverRealtimeQuoteDto? realtimeQuote,
    required DateTime? latestDate,
  }) {
    final isLatest =
        latestDate != null &&
        normalizeAsOfDate(historicalEntry.row.localDate) == latestDate;
    final currentPrice = isLatest && realtimeQuote != null
        ? realtimeQuote.currentPrice
        : historicalEntry.row.closePrice;
    final changeRate = isLatest && realtimeQuote != null
        ? realtimeQuote.changeRate
        : _percentChange(
            currentPrice - historicalEntry.previousClose,
            historicalEntry.previousClose,
          );
    final tradeVolume = isLatest && realtimeQuote != null
        ? realtimeQuote.accumulatedTradingVolume
        : historicalEntry.row.accumulatedTradingVolume;
    final marketCap = realtimeQuote == null
        ? 0
        : (realtimeQuote.countOfListedStock * realtimeQuote.currentPrice)
              .round();

    return WatchlistItem(
      id: canonicalDomesticFavoriteId(symbol),
      market: MarketType.domestic,
      symbol: symbol,
      name: metadata.stockName,
      currency: 'KRW',
      currentPrice: currentPrice,
      changeRate: changeRate,
      tradeVolume: tradeVolume,
      marketCap: marketCap,
      logoUrl: _logoUrlResolver.resolveDomesticStockLogoUrl(symbol),
    );
  }

  DateTime _resolveAsOf(
    List<DateTime> availableDates,
    DateTime? requestedAsOf,
  ) {
    if (availableDates.isEmpty) {
      return normalizeAsOfDate(requestedAsOf ?? DateTime.now());
    }

    if (requestedAsOf == null) {
      return availableDates.first;
    }

    final normalizedAsOf = normalizeAsOfDate(requestedAsOf);
    for (final date in availableDates) {
      if (date == normalizedAsOf) {
        return date;
      }
    }

    return availableDates.first;
  }

  int? _indexOfDate(List<DateTime> availableDates, DateTime asOf) {
    final normalizedAsOf = normalizeAsOfDate(asOf);
    for (var index = 0; index < availableDates.length; index += 1) {
      if (availableDates[index] == normalizedAsOf) {
        return index;
      }
    }
    return null;
  }

  int _pageNumberForIndex(int index) {
    return (index ~/ _historyRowsPerPage) + 1;
  }

  NaverHistoricalPriceDto? _rowForDate(
    Iterable<NaverHistoricalPriceDto> rows,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);
    for (final row in rows) {
      if (_dateKey(row.localDate) == dateKey) {
        return row;
      }
    }
    return null;
  }

  double _volumeRatio({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    if (windowDatesDescending.isEmpty) {
      return 0;
    }

    final selectedRow = rowsByDate[_dateKey(windowDatesDescending.first)];
    if (selectedRow == null) {
      return 0;
    }

    final previousVolumes = <int>[];
    for (
      var index = 1;
      index < windowDatesDescending.length && previousVolumes.length < 5;
      index += 1
    ) {
      final row = rowsByDate[_dateKey(windowDatesDescending[index])];
      if (row != null) {
        previousVolumes.add(row.accumulatedTradingVolume);
      }
    }

    if (previousVolumes.isEmpty) {
      return 0;
    }

    final averageVolume =
        previousVolumes.reduce((left, right) => left + right) /
        previousVolumes.length;
    if (averageVolume == 0) {
      return 0;
    }

    return double.parse(
      (selectedRow.accumulatedTradingVolume / averageVolume).toStringAsFixed(2),
    );
  }

  List<CandlePoint> _candles({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    return windowDatesDescending.reversed
        .map((date) => rowsByDate[_dateKey(date)])
        .whereType<NaverHistoricalPriceDto>()
        .map(
          (item) => CandlePoint(
            time: item.localDate,
            open: item.openPrice,
            high: item.highPrice,
            low: item.lowPrice,
            close: item.closePrice,
            direction: directionFromDelta(item.closePrice - item.openPrice),
          ),
        )
        .toList(growable: false);
  }

  bool _isCanonicalFavoriteId(String itemId) {
    return domesticSymbolFromFavoriteId(itemId) != null;
  }

  String _requireCanonicalFavoriteId(String itemId) {
    final symbol = domesticSymbolFromFavoriteId(itemId);
    if (symbol == null) {
      throw ArgumentError.value(
        itemId,
        'itemId',
        'Naver repository only accepts canonical domestic favorite ids',
      );
    }
    return canonicalDomesticFavoriteId(symbol);
  }

  String _dailyHistoryPageCacheKey(String symbol, int page) => '$symbol::$page';

  String _dateKey(DateTime value) => formatApiDate(value);

  double _percentChange(double delta, double base) {
    if (base == 0) {
      return 0;
    }
    return double.parse(((delta / base) * 100).toStringAsFixed(2));
  }
}

class _RealtimeQuoteCacheEntry {
  const _RealtimeQuoteCacheEntry({
    required this.quote,
    required this.fetchedAt,
  });

  final NaverRealtimeQuoteDto quote;
  final DateTime fetchedAt;
}

class _HistoricalEntry {
  const _HistoricalEntry({required this.row, required this.previousClose});

  final NaverHistoricalPriceDto row;
  final double previousClose;
}
