# Assignment Note

---

## DTO 파싱 (NaverAutocompleteItemDto / NaverRealtimeQuoteDto / NaverChartMetadataDto / NaverHistoricalPriceDto / NaverHistoricalChartDto)

### 구현 방식 및 설계

파일 하단에 이미 정의된 `_readString`, `_readDouble`, `_readInt`, `_readNullableInt`, `_readLocalDate` 헬퍼 함수를 활용하여 5개의 `fromJson` 팩토리를 구현하였습니다.

- **NaverAutocompleteItemDto**: `code`, `name`, `typeCode`, `typeName`, `url`, `nationCode`, `category` 7개 필드를 모두 `_readString`으로 매핑하였습니다. 국내 6자리 종목 필터링은 `isDomesticStock` getter에 이미 구현되어 있어 `fromJson`에서는 순수 파싱만 담당하였습니다.
- **NaverRealtimeQuoteDto**: Naver 실시간 시세 응답의 축약 키(`cd`, `nv`, `pcv`, `ov`, `hv`, `lv`, `aq`)를 의미 있는 필드명으로 매핑하였습니다. `changeAmount`와 `changeRate`는 이미 getter로 구현되어 있으므로 `fromJson`에서 직접 계산하지 않았습니다.
- **NaverChartMetadataDto**: 메타데이터 API의 `symbolCode` 키를 DTO의 `symbol` 필드로 매핑하였습니다. (API 응답 키와 필드명이 상이함)
- **NaverHistoricalPriceDto**: `localDate`는 `_readLocalDate`를 사용하여 `yyyyMMdd` 8자리 문자열을 `DateTime`으로 변환하였습니다. 내부적으로 `normalizeAsOfDate`를 거치므로 시간 정보가 제거됩니다.
- **NaverHistoricalChartDto**: `priceInfos` 배열의 각 원소를 `NaverHistoricalPriceDto.fromJson`으로 변환하였습니다. `json['code']` 키를 `symbol` 필드에 매핑하였습니다.

### Technical Trade-off

**헬퍼 함수 재사용 vs 직접 캐스팅**

`_readDouble`, `_readInt` 등의 헬퍼는 값이 `num`, `int`, `String` 중 어떤 타입으로 오더라도 처리할 수 있도록 구현되어 있습니다. Naver API 응답에서 숫자 필드가 정수(`int`)로 올 수도 있고 문자열(`String`, 예: `"67,000"`)로 올 수도 있어, 직접 `as int` 또는 `as double`로 캐스팅할 경우 런타임 오류가 발생할 수 있습니다. 헬퍼 함수를 사용하면 이 문제를 일관되게 처리할 수 있습니다.

**`_readLocalDate`의 정규화 선택**

`normalizeAsOfDate`를 통해 시간 정보를 제거(`DateTime(year, month, day)`)하는 이유는, 나중에 날짜를 비교할 때 `==` 연산자를 안전하게 사용할 수 있도록 하기 위함입니다. 시간 정보가 남아 있으면 같은 날짜라도 두 `DateTime`이 다른 값으로 판정될 수 있습니다.

**`countOfListedStock`의 nullable 처리**

해당 필드는 실시간 시세 API에서 항상 제공되지 않을 수 있습니다. `_readNullableInt`로 읽은 후 `?? 0` fallback을 적용하여 `null`일 때 시총 계산(`countOfListedStock * currentPrice`)에서 오류가 발생하지 않도록 하였습니다.

### 가정 및 전제

- **localDate 형식**: Naver 역사 데이터 API는 항상 `yyyyMMdd` 형식의 8자리 문자열을 반환한다고 가정하였습니다. 형식이 다를 경우 `_readLocalDate` 내부에서 `FormatException`이 발생합니다.
- **priceInfos 타입**: `NaverHistoricalChartDto.fromJson`에서 `json['priceInfos']`가 `List<dynamic>` 타입임을 가정하였습니다. 키가 없거나 타입이 다를 경우 런타임 오류가 발생하며, 이는 상위 레이어(Client/Repository)의 오류 처리 로직에서 처리됩니다.
- **국내 종목 필터링 책임 분리**: `isDomesticStock` 필터링은 Client/Repository 레이어에서 수행하므로, DTO의 `fromJson`은 파싱 실패 시 예외만 throw하고 별도 필터링 로직을 포함하지 않습니다.
