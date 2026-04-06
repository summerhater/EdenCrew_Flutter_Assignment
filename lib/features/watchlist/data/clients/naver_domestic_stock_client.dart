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
    final items = body['items'] as List<dynamic>;
    // {"code":"005930","name":"삼성전자","typeCode":"KOSPI",..}같이
    // 1차원 배열 형식으로 들어오므로 따로 배열 가공 필요 없이 바로 DTO 가공 단계로 넘김
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
    // 빈 symbols 미리 처리로 불필요한 네트워크 요청 방지
    if (uniqueSymbols.isEmpty) return {};

    final queryParam =
        uniqueSymbols.map((s) => 'SERVICE_ITEM:$s').join('|');

    final response = await _dio.get<Object>(
      'https://polling.finance.naver.com/api/realtime',
      queryParameters: {'query': queryParam},
      options: Options(headers: _defaultHeaders, responseType: ResponseType.plain),
    );

    final body = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');

    // result → areas → datas 차례대로 접근
    final result = _asStringKeyedMap(body['result'], 'fetchRealtimeQuotes result');

    final areas = result['areas'] as List<dynamic>;

    // 국내 주식만 담기 때문에 응답의 areas는 항상 원소가 1개라서 .first로 접근
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

    // 아래 순서대로 파싱
    // HTTP Dio로 요청 + latin1 디코딩
    final html = await _fetchDailyHistoryHtml(symbol: symbol, page: page);
    // 페이지네이션에서 마지막 페이지 넘버 알아내기
    final lastPage = _extractLastPage(html, currentPage: page);
    // HTML에서 가격 행 전체 파싱
    final priceInfos = _parsePriceRows(html);

    return NaverDailyHistoryPageDto(
      symbol: symbol,
      page: page,
      lastPage: lastPage,
      priceInfos: priceInfos,
    );
  }

  Future<String> _fetchDailyHistoryHtml({
    required String symbol,
    required int page,
  }) async {
    final response = await _dio.get<Object>(
      'https://finance.naver.com/item/sise_day.naver',
      queryParameters: {'code': symbol, 'page': page},
      options: Options(headers: _defaultHeaders, responseType: ResponseType.bytes),
    );

    final bytes = response.data;
    // response.data가 List<int>가 아닐 경우 에러처리
    // response.data가 List<int>가 아닌 것은 Dio 설정이 바뀌는 등등 내부 상태 이상이지,
    // 잘못된 입력값 X -> 입력값 오류(ArgumentError)와 구분하기 위해 StateError를 사용
    if (bytes is! List<int>) throw StateError('Expected bytes response');

    // EUC-KR로 인코딩 -> 코드포인트가 그대로 보존되서 한글 안깨짐 -> 정규식 파싱 가능
    return latin1.decode(bytes);
  }

  int _extractLastPage(String html, {required int currentPage}) {
    // page=N 패턴 최댓값으로 lastPage 추출, 페이지네이션 링크가 없으면 현재 페이지 번호를 유지
    var lastPage = currentPage;
    for (final m in RegExp(r'page=(\d+)').allMatches(html)) {
      final p = int.tryParse(m.group(1)!) ?? 0;
      if (p > lastPage) lastPage = p;
    }
    return lastPage;
  }

  List<NaverHistoricalPriceDto> _parsePriceRows(String html) {
    // <tr>→<td> 중첩 정규식으로 파싱
    // - 날짜 패턴(yyyy.MM.dd)이 첫 번째 셀에 있는 행만 데이터 행으로 판단
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final tdPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    final tagPattern = RegExp(r'<[^>]+>');
    final datePattern = RegExp(r'^\d{4}\.\d{2}\.\d{2}$');

    final priceInfos = <NaverHistoricalPriceDto>[];

    for (final rowMatch in rowPattern.allMatches(html)) {
      // 단일 table row에서 셀 텍스트 추출
      final cells = _extractCells(rowMatch.group(1)!, tdPattern, tagPattern);

      if (cells.length < 7 || !datePattern.hasMatch(cells[0])) continue;

      // 추출한 셀 텍스트 분해해서 DTO 변환
      priceInfos.add(_buildPriceDto(cells));
    }

    return priceInfos;
  }

  List<String> _extractCells(
      String rowHtml,
      RegExp tdPattern,
      RegExp tagPattern,
      ) {
    return tdPattern
        .allMatches(rowHtml)
        .map(
          (m) => m
          .group(1)!
          .replaceAll(tagPattern, '')
          .replaceAll('&nbsp;', '') // 제거 안하면 trim()만으로는 공백이 남아 숫자 파싱 실패
          .trim(),
    )
        .toList();
  }

  NaverHistoricalPriceDto _buildPriceDto(List<String> cells) {
    return NaverHistoricalPriceDto.fromJson({
      'localDate': cells[0].replaceAll('.', ''), // yyyy.MM.dd → yyyyMMdd
      'closePrice': cells[1],
      'openPrice': cells[3],
      'highPrice': cells[4],
      'lowPrice': cells[5],
      'accumulatedTradingVolume': cells[6],
    });
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