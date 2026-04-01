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

---

## API Client (NaverDomesticStockClient)

### 구현 방식 및 설계

`NaverDomesticStockClient`의 4개 메서드를 구현하였습니다. 파일 상단에 이미 정의된 `_decodeJsonObjectBody`, `_asStringKeyedMap`, `_defaultHeaders` 헬퍼와 상수를 활용하였습니다.

- **`searchStocks`**: `https://ac.stock.naver.com/ac`에 `q`, `target` 쿼리 파라미터로 GET 요청하였습니다. `ResponseType.plain`을 사용하여 응답이 문자열로 오더라도 `_decodeJsonObjectBody`에서 안전하게 디코딩되도록 하였습니다. Naver 자동완성 API가 `items`를 중첩 배열(`List<List<dynamic>>`)로 반환하는 경우도 있어 첫 원소 타입 검사 후 flatten 처리를 추가하였습니다.
- **`fetchRealtimeQuotes`**: `symbols`를 중복 제거 후 `SERVICE_ITEM:{symbol}` 형식으로 조립하여 `|`로 연결, 단일 요청으로 여러 종목의 실시간 시세를 취득합니다. 응답 구조 `result → areas[0] → datas`를 순회하며 각 항목을 `NaverRealtimeQuoteDto.fromJson`으로 변환하고 symbol 기준 Map으로 반환합니다.
- **`fetchChartMetadata`**: `https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}`에 GET 요청 후 `NaverChartMetadataDto.fromJson`으로 변환합니다.
- **`fetchDailyHistoryPage`**: `https://finance.naver.com/item/sise_day.naver`에서 HTML을 `ResponseType.bytes`로 수신한 뒤 `latin1.decode`로 디코딩합니다. `<tr>/<td>` 중첩 정규식으로 테이블 행을 파싱하고, 첫 번째 셀이 `yyyy.MM.dd` 패턴인 행만 데이터 행으로 판별합니다.

### Technical Trade-off

**`searchStocks`의 items 구조 처리: 중첩 배열 vs 평탄 배열**

Naver 자동완성 API 응답의 `items` 필드는 `target` 파라미터에 따라 중첩 배열(`[[item1, item2], [item3]]`)이나 평탄 배열(`[item1, item2, item3]`) 형태로 올 수 있습니다. `items.first is List<dynamic>` 타입 검사를 통해 중첩 구조를 감지하여 `expand`로 flatten하는 방식을 선택하였습니다. 단순히 `body['items']`를 직접 순회할 경우 중첩 구조에서 런타임 캐스트 오류가 발생하기 때문입니다.

**`fetchDailyHistoryPage`의 HTML 파싱: 정규식 vs HTML 파서 라이브러리**

새 패키지 추가가 금지된 제약 조건에서 `html` 파서 라이브러리를 사용할 수 없으므로 정규식을 선택하였습니다. `<tr[^>]*>(.*?)</tr>` → `<td[^>]*>(.*?)</td>` 중첩 패턴으로 테이블 구조를 파싱합니다. HTML 파서보다 깨지기 쉽지만, Naver Finance의 레거시 페이지는 구조가 안정적이며 변경 가능성이 낮다고 판단하였습니다.

**`latin1.decode` 사용 이유**

네이버 금융의 `sise_day.naver`는 EUC-KR 인코딩이지만, Dart 표준 라이브러리에는 EUC-KR 디코더가 없습니다. `latin1`은 `0x00`–`0xFF` 바이트를 1:1로 유니코드 코드포인트에 매핑하므로, EUC-KR 멀티바이트 문자를 깨뜨리지 않고 ASCII와 숫자 범위의 데이터(날짜, 숫자)를 정확히 추출할 수 있습니다. 한글 종목명이 포함된 셀은 파싱하지 않으므로 실용적 문제가 없습니다.

**`fetchRealtimeQuotes`의 빈 symbols 조기 반환**

symbols가 비어 있을 때 HTTP 요청 없이 즉시 빈 Map을 반환합니다. 이를 통해 불필요한 네트워크 비용을 방지하고, 호출 측에서 빈 결과를 일관되게 처리할 수 있습니다.

### 가정 및 전제

- **HTML 구조 안정성**: `fetchDailyHistoryPage`는 Naver Finance 테이블 HTML 구조가 일정하다고 가정합니다. 테이블 컬럼 순서(날짜, 종가, 전일비, 시가, 고가, 저가, 거래량)가 변경될 경우 파싱 결과가 달라집니다.
- **`lastPage` 추출**: `page=N` 패턴 최댓값을 lastPage로 사용합니다. 페이지네이션 링크가 없는 경우(단일 페이지) 현재 `page` 값이 lastPage가 됩니다.
- **realtime API 응답 구조**: `result → areas → datas` 경로가 항상 존재한다고 가정합니다. 구조가 없을 경우 `_asStringKeyedMap`에서 `FormatException`이 발생하며, 이는 상위 Repository의 오류 처리 로직에서 catch됩니다.
- **`fetchChartMetadata` 응답**: `symbolCode`, `stockName`, `stockExchangeNameKor` 필드가 항상 존재한다고 가정합니다. 없을 경우 `_readString`에서 `FormatException`이 발생합니다.
