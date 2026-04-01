// ignore_for_file: unused_element, unused_field

import 'dart:convert';

import 'package:dio/dio.dart';

import '../dtos/naver_stock_dtos.dart';

abstract interface class NaverStockDataClient {
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query);

  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  );

  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol);

  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  });
}

class NaverDomesticStockClient implements NaverStockDataClient {
  const NaverDomesticStockClient(this._dio);

  final Dio _dio;

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://m.stock.naver.com/',
    'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/123.0.0.0 Safari/537.36',
  };

  static Map<String, dynamic> _decodeJsonObjectBody(
    Object? data,
    String contextLabel,
  ) {
    if (data == null) {
      throw FormatException('$contextLabel response body is empty');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel response body has unsupported shape');
  }

  static Map<String, dynamic> _asStringKeyedMap(
    Object? value,
    String contextLabel,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel is not a JSON object');
  }

  @override
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query) async {
    // TODO(assignment): Implement the Naver autocomplete request.
    //
    // Goal:
    // - Call https://ac.stock.naver.com/ac with Dio.
    // - Send q=<query> and target=stock,ipo,index,marketindicator.
    // - Use _defaultHeaders and ResponseType.plain because the response body
    //   may arrive as a String instead of a decoded JSON map.
    // - Decode the response with _decodeJsonObjectBody.
    // - Read the "items" array and map each entry with
    //   NaverAutocompleteItemDto.fromJson.
    //
    // Related tests:
    // - test/features/watchlist/data/naver_stock_dtos_test.dart
    // - test/features/watchlist/data/naver_watchlist_repository_test.dart
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverDomesticStockClient.searchStocks',
    // );

    final response = await _dio.get<Object>(
      'https://ac.stock.naver.com/ac',
      queryParameters: {
        'q': query,
        'target': 'stock,ipo,index,marketindicator',
      },
      options: Options(headers: _defaultHeaders, responseType: ResponseType.plain),
    );
    final body = _decodeJsonObjectBody(response.data, 'searchStocks');
    final raw = body['items'] as List<dynamic>;
    // Note(assignment): Naver 자동완성 API는 items를 중첩 배열로 반환할 수 있음 —
    // 첫 원소가 List이면 flatten, 아니면 그대로 사용
    final items = raw.isNotEmpty && raw.first is List<dynamic>
        ? raw.expand((e) => e as List<dynamic>).toList()
        : raw;
    return items
        .map((e) => NaverAutocompleteItemDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // TODO(assignment): Implement the Naver realtime quote request.
    //
    // Goal:
    // - Deduplicate the incoming symbols.
    // - Return an empty map when there is nothing to request.
    // - Build query=SERVICE_ITEM:005930|SERVICE_ITEM:000660 style payload.
    // - Call https://polling.finance.naver.com/api/realtime.
    // - Decode the JSON body, then traverse result -> areas -> datas.
    // - Convert each realtime row with NaverRealtimeQuoteDto.fromJson.
    // - Return a map keyed by the six-digit domestic symbol.
    //
    // Note:
    // - The response body may be plain text JSON, so use ResponseType.plain.
    // - Some tests use a fake client, but the real app depends on this method.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverDomesticStockClient.fetchRealtimeQuotes',
    // );

    final uniqueSymbols = symbols.toSet();
    // Note(assignment): 빈 symbols 조기 반환 — 불필요한 HTTP 요청 방지
    if (uniqueSymbols.isEmpty) return {};

    final queryParam =
        uniqueSymbols.map((s) => 'SERVICE_ITEM:$s').join('|');
    final response = await _dio.get<Object>(
      'https://polling.finance.naver.com/api/realtime',
      queryParameters: {'query': queryParam},
      options: Options(headers: _defaultHeaders, responseType: ResponseType.plain),
    );
    final body = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');
    final result = _asStringKeyedMap(body['result'], 'fetchRealtimeQuotes result');
    final areas = result['areas'] as List<dynamic>;
    final datas = _asStringKeyedMap(
      areas.first,
      'fetchRealtimeQuotes areas[0]',
    )['datas'] as List<dynamic>;

    final map = <String, NaverRealtimeQuoteDto>{};
    for (final data in datas) {
      final dto = NaverRealtimeQuoteDto.fromJson(
        _asStringKeyedMap(data, 'fetchRealtimeQuotes data'),
      );
      map[dto.symbol] = dto;
    }
    return map;
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    // TODO(assignment): Implement the chart metadata request.
    //
    // Goal:
    // - Call
    //   https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}
    // - Decode the JSON object with _decodeJsonObjectBody.
    // - Convert the payload with NaverChartMetadataDto.fromJson.
    //
    // Required fields for the DTO:
    // - symbolCode
    // - stockName
    // - stockExchangeNameKor
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverDomesticStockClient.fetchChartMetadata',
    // );

    final response = await _dio.get<Object>(
      'https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/$symbol',
      options: Options(headers: _defaultHeaders),
    );
    final body = _decodeJsonObjectBody(response.data, 'fetchChartMetadata');
    return NaverChartMetadataDto.fromJson(body);
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    // TODO(assignment): Implement parsing for the legacy daily history page.
    //
    // Goal:
    // - Validate that page >= 1.
    // - Request https://finance.naver.com/item/sise_day.naver
    //   with code=<symbol> and page=<page>.
    // - Use ResponseType.bytes and decode the HTML with latin1.
    // - Parse one page of historical rows from the HTML table.
    // - For each row, extract:
    //   - localDate (yyyyMMdd)
    //   - closePrice
    //   - openPrice
    //   - highPrice
    //   - lowPrice
    //   - accumulatedTradingVolume
    // - Also extract lastPage from the pagination area.
    //
    // Hint:
    // - The rendered table order is close, change, open, high, low, volume.
    // - You can keep using NaverHistoricalPriceDto.fromJson to build rows.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverDomesticStockClient.fetchDailyHistoryPage',
    // );

    if (page < 1) throw ArgumentError.value(page, 'page', 'page must be >= 1');

    final response = await _dio.get<Object>(
      'https://finance.naver.com/item/sise_day.naver',
      queryParameters: {'code': symbol, 'page': page},
      options: Options(headers: _defaultHeaders, responseType: ResponseType.bytes),
    );

    // Note(assignment): latin1 사용 — 네이버 금융 레거시 HTML이 EUC-KR 기반이며
    // latin1은 0x00-0xFF를 1:1 매핑하므로 바이트 손실 없이 디코딩 후 파싱 가능
    final html = latin1.decode(response.data as List<int>);

    // Note(assignment): page=N 패턴 최댓값으로 lastPage 추출 —
    // 페이지네이션 링크가 없으면 현재 페이지 번호를 유지
    var lastPage = page;
    for (final m in RegExp(r'page=(\d+)').allMatches(html)) {
      final p = int.tryParse(m.group(1)!) ?? 0;
      if (p > lastPage) lastPage = p;
    }

    // Note(assignment): <tr>→<td> 중첩 정규식으로 파싱 —
    // 날짜 패턴(yyyy.MM.dd)이 첫 번째 셀에 있는 행만 데이터 행으로 판별
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final tdPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    final tagPattern = RegExp(r'<[^>]+>');
    final datePattern = RegExp(r'^\d{4}\.\d{2}\.\d{2}$');

    final priceInfos = <NaverHistoricalPriceDto>[];

    for (final rowMatch in rowPattern.allMatches(html)) {
      final cells = tdPattern
          .allMatches(rowMatch.group(1)!)
          .map(
            (m) => m
                .group(1)!
                .replaceAll(tagPattern, '')
                .replaceAll('&nbsp;', '')
                .trim(),
          )
          .toList();

      // 컬럼: [0]날짜 [1]종가 [2]전일비(skip) [3]시가 [4]고가 [5]저가 [6]거래량
      if (cells.length < 7 || !datePattern.hasMatch(cells[0])) continue;

      priceInfos.add(
        NaverHistoricalPriceDto.fromJson({
          'localDate': cells[0].replaceAll('.', ''), // yyyy.MM.dd → yyyyMMdd
          'closePrice': cells[1],
          'openPrice': cells[3],
          'highPrice': cells[4],
          'lowPrice': cells[5],
          'accumulatedTradingVolume': cells[6],
        }),
      );
    }

    return NaverDailyHistoryPageDto(
      symbol: symbol,
      page: page,
      lastPage: lastPage,
      priceInfos: priceInfos,
    );
  }
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
