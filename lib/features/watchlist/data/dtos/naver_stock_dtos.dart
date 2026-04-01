// ignore_for_file: unused_element

import '../../domain/services/watchlist_sorting.dart';

class NaverAutocompleteItemDto {
  const NaverAutocompleteItemDto({
    required this.code,
    required this.name,
    required this.typeCode,
    required this.typeName,
    required this.url,
    required this.nationCode,
    required this.category,
  });

  factory NaverAutocompleteItemDto.fromJson(Map<String, dynamic> json) {
    // TODO(assignment): Read the autocomplete fields from json and create the
    // DTO. See README.md for the expected Naver endpoint and sample payload.
    //
    // Required fields:
    // - code
    // - name
    // - typeCode
    // - typeName
    // - url
    // - nationCode
    // - category
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverAutocompleteItemDto.fromJson',
    // );

    return NaverAutocompleteItemDto(
      code:       _readString(json['code']),
      name:       _readString(json['name']),
      typeCode:   _readString(json['typeCode']),
      typeName:   _readString(json['typeName']),
      url:        _readString(json['url']),
      nationCode: _readString(json['nationCode']),
      category:   _readString(json['category']),
    );
  }

  final String code;
  final String name;
  final String typeCode;
  final String typeName;
  final String url;
  final String nationCode;
  final String category;

  bool get isDomesticStock =>
      category == 'stock' &&
      nationCode == 'KOR' &&
      RegExp(r'^\d{6}$').hasMatch(code) &&
      url.contains('/domestic/stock/');
}

class NaverRealtimeQuoteDto {
  const NaverRealtimeQuoteDto({
    required this.symbol,
    required this.currentPrice,
    required this.previousClose,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.accumulatedTradingVolume,
    required this.countOfListedStock,
  });

  factory NaverRealtimeQuoteDto.fromJson(Map<String, dynamic> json) {
    // TODO(assignment): Map the realtime quote payload into this DTO.
    //
    // Naver keys used by the solution:
    // - cd: symbol
    // - nv: current price
    // - pcv: previous close
    // - ov: open price
    // - hv: high price
    // - lv: low price
    // - aq: accumulated trading volume
    // - countOfListedStock: listed share count (optional)
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverRealtimeQuoteDto.fromJson',
    // );

    // Note(assignment): countOfListedStock은 없을 경우 0으로
    // fallback하여 marketCap 계산 시 null 예외 방지
    return NaverRealtimeQuoteDto(
      symbol:                   _readString(json['cd']),
      currentPrice:             _readDouble(json['nv']),
      previousClose:            _readDouble(json['pcv']),
      openPrice:                _readDouble(json['ov']),
      highPrice:                _readDouble(json['hv']),
      lowPrice:                 _readDouble(json['lv']),
      accumulatedTradingVolume: _readInt(json['aq']),
      countOfListedStock:       _readNullableInt(json['countOfListedStock']) ?? 0,
    );
  }

  final String symbol;
  final double currentPrice;
  final double previousClose;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int accumulatedTradingVolume;
  final int countOfListedStock;

  double get changeAmount => currentPrice - previousClose;

  double get changeRate {
    if (previousClose == 0) {
      return 0;
    }
    return double.parse(
      (((currentPrice - previousClose) / previousClose) * 100).toStringAsFixed(
        2,
      ),
    );
  }
}

class NaverChartMetadataDto {
  const NaverChartMetadataDto({
    required this.symbol,
    required this.stockName,
    required this.stockExchangeNameKor,
  });

  factory NaverChartMetadataDto.fromJson(Map<String, dynamic> json) {
    // TODO(assignment): Map the chart metadata payload into this DTO.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverChartMetadataDto.fromJson',
    // );

    return NaverChartMetadataDto(
      symbol:               _readString(json['symbolCode']),
      stockName:            _readString(json['stockName']),
      stockExchangeNameKor: _readString(json['stockExchangeNameKor']),
    );
  }

  final String symbol;
  final String stockName;
  final String stockExchangeNameKor;
}

class NaverHistoricalPriceDto {
  const NaverHistoricalPriceDto({
    required this.localDate,
    required this.closePrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.accumulatedTradingVolume,
  });

  factory NaverHistoricalPriceDto.fromJson(Map<String, dynamic> json) {
    // TODO(assignment): Parse one historical OHLCV row.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverHistoricalPriceDto.fromJson',
    // );

    // Note(assignment): _readLocalDate가 yyyyMMdd 8자리 문자열을 DateTime으로 변환하며
    // normalizeAsOfDate로 시간 정보를 제거 — 날짜 동등 비교 시 시간 불일치 방지
    return NaverHistoricalPriceDto(
      localDate:                _readLocalDate(json['localDate']),
      closePrice:               _readDouble(json['closePrice']),
      openPrice:                _readDouble(json['openPrice']),
      highPrice:                _readDouble(json['highPrice']),
      lowPrice:                 _readDouble(json['lowPrice']),
      accumulatedTradingVolume: _readInt(json['accumulatedTradingVolume']),
    );
  }

  final DateTime localDate;
  final double closePrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int accumulatedTradingVolume;
}

class NaverHistoricalChartDto {
  const NaverHistoricalChartDto({
    required this.symbol,
    required this.periodType,
    required this.priceInfos,
  });

  factory NaverHistoricalChartDto.fromJson(Map<String, dynamic> json) {
    // TODO(assignment): Parse the chart wrapper and convert each priceInfos
    // entry with NaverHistoricalPriceDto.fromJson.
    // throw UnimplementedError(
    //   'TODO(assignment): implement NaverHistoricalChartDto.fromJson',
    // );

    // Note(assignment): json['code'] 키를 symbol에 매핑
    // —> API 응답의 최상위 식별자가 'code'이므로
    final rawPriceInfos = json['priceInfos'] as List<dynamic>;
    return NaverHistoricalChartDto(
      symbol:     _readString(json['code']),
      periodType: _readString(json['periodType']),
      priceInfos: rawPriceInfos
          .map((e) => NaverHistoricalPriceDto.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String symbol;
  final String periodType;
  final List<NaverHistoricalPriceDto> priceInfos;
}

class NaverDailyHistoryPageDto {
  const NaverDailyHistoryPageDto({
    required this.symbol,
    required this.page,
    required this.lastPage,
    required this.priceInfos,
  });

  final String symbol;
  final int page;
  final int lastPage;
  final List<NaverHistoricalPriceDto> priceInfos;
}

DateTime _readLocalDate(Object? value) {
  final text = _readString(value);
  if (text.length != 8) {
    throw FormatException('Invalid Naver localDate "$text"');
  }

  return normalizeAsOfDate(
    DateTime(
      int.parse(text.substring(0, 4)),
      int.parse(text.substring(4, 6)),
      int.parse(text.substring(6, 8)),
    ),
  );
}

String _readString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw FormatException('Missing string value for "$value"');
  }
  return text;
}

double _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(_readString(value).replaceAll(',', ''));
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.parse(_readString(value).replaceAll(',', ''));
}

int? _readNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _readInt(value);
}
