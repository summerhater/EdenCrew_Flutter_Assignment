# Assignment Note
작성자 : 최란

---
## Notice
- 과제의 `// TODO(assignment): ...` 가이드 주석은 구현 완료 후에도 구현 위치 명시와, `문제-해결 구조`를 명확하게 하기 위해 삭제하지 않았습니다.
- 코드는 `// TODO(assignment): ...` 가이드 주석 하단에 구현했습니다.
- 이 과제를 진행하며, 저는 AI를 아래와 같은 목적으로 활용했습니다.
  1. 기존 메서드를 활용하기 위해, 프로젝트 구조와 기존 코드의 목적을 빠르게 파악하는데에 활용했습니다.
  2. 코드 리뷰어로써, 작성한 코드에서 놓친 부분을 제안하게 하고, 선택적인 수용을 하며 코드 플로우 및 품질을 개선하는데에 활용했습니다.
  3. API 응답 구조를 확인하고, 테스트 실패 원인을 분석하는 디버깅 보조 도구로 사용했습니다.
  

## 구현 순서
flutter test로 구현이 필요한 부분을 먼저 확인하고 아래의 순서대로 구현을 했습니다.

1. DTO 작성 (`naver_stock_dtos.dart`)
2. API Client (`naver_domestic_stock_client.dart`)
3. Repository (`naver_watchlist_repository.dart`)
4. SearchController (`search_controller.dart`)
5. UI — SearchResultRow, SearchToast, WatchlistDateBottomSheet
6. UI — WatchlistScreen 날짜 동기화
7. UI — 바텀시트 SafeArea 구조 수정 및 골든 테스트를 통한 전반적인 UI 마이너 수정
8. 1~4번 리팩토링 및 마이너 수정

---

<br>

## 구현 전제
아래의 가정을 두고 구현했습니다.

- 네이버 자동완성 API의 `items`는 항상 1차원 배열로 반환됩니다.
- 네이버 실시간 시세 응답의 `result → areas → datas` 경로는 항상 존재합니다.
- 국내 종목을 단일 요청하면 `areas`는 원소가 1개입니다.
- `sise_day.naver` HTML 테이블 column 순서(날짜/종가/전일비/시가/고가/저가/거래량)는 항상 같습니다.
- 국내 종목은 모두 KRX 거래일을 공유하므로 `fetchAvailableDates`의 기준 종목은 아무거나 써도 됩니다.
- `countOfListedStock`은 API에서 항상 내려오지 않을 수 있어 `null`이면 0으로 fallback했습니다.
- 해외 종목은 구현하지 않습니다. (`fetchWatchlistDetail`에서 `UnsupportedError`).

---

<br>

## 아직 남은 이슈

**골든 테스트 일부 fail**
  | No. | 테스트 항목 (Test Description) | 결과 | 실패 사유 | 픽셀 차이 (Diff) | 관련 파일 |
  | :---: | :--- | :---: | :--- | :---: | :--- |
  | **1** | **matches the search results screen at 360 width** | 실패 | Golden 이미지 불일치 | **0.20%** (647px) | `search_results_selected.png` |
  | **2** | **matches the favorite toast state at 360 width** | 실패 | Golden 이미지 불일치 | **1.93%** (6348px) | `search_results_toast.png` |

Figma 기준으로 맞추는 UI 구현이 과제의 핵심 중 하나이기에, **의도적으로 fail 한 상태로 과제를 제출하게 되었습니다.** 

- 원인 분석
  1. search results 원인
    - 뉴스/종목토론 버튼(searchActionBar)의 구분선 : figma에는 구분선이 없지만 골든 이미지에는 구분선이 있습니다. figma 기준으로 맞추기 위해 _SearchActionDivider()를 주석으로 숨겼습니다.
    - Subtitle의 '|' 구분선 : figma와 골든 이미지의 구분선 색상이 다릅니다. figma 기준으로 맞췄습니다.
  2. favorite toast state 원인
    - 1과 마찬가지로 Subtitle의 '|' 구분선 색상이 다릅니다.
    - 골든 이미지에서는 하트 아이콘과 토스트 메세지가 수평 중앙 정렬이 아닙니다. figma 상에서는 수평 중앙 정렬이므로 토스트 메세지 위치가 다릅니다.
    - 골든 이미지에서는 토스트 배경 오른쪽에 반투명의 보라색 원이 클리핑 마스크 처리가 되어 있는 걸로 보입니다. figma 상에서는 해당 디자인 요소가 없기때문에 구현하지 않았습니다.
    - 골든 이미지에서는 토스트에 boxShadow가 없습니다. figma에서는 boxShadow가 구현 되어 있기에, 그림자를 넣어줬습니다 -> 그림자 차이가 발생합니다.

---

<br>

## 테스트 결과 (제출 시점 기준)

#### flutter analyze

```
Analyzing Edencrew_assignment...
No issues found!
```

---

#### flutter test
위의 `아직 남은 이슈`에 명시된 2개 골든 테스트 fail을 포함한 로그입니다.
```
00:04 +51 -2: Some tests failed.
```

---

#### desktop integration

```
== Running integration_test/root/favorite_sync_flow_test.dart on macos ==
00:32 +1: All tests passed!
== Running integration_test/watchlist/watchlist_flow_test.dart on macos ==
00:20 +2: All tests passed!
```

---

<br>

## 과제별 구현 설명

---

### 1. DTO 작성 (`naver_stock_dtos.dart`)

**어떻게 구현했는지**

파일 하단에 이미 정의된 `_readString`, `_readDouble`, `_readInt`, `_readNullableInt`, `_readLocalDate` 헬퍼를 활용해 5개의 `fromJson` factory를 구현했습니다.

**왜 그렇게 했는지**

Naver API 응답에서 숫자 필드는 `int`, `double`, `String("67,000")` 중 어떤 타입으로도 올 수 있습니다. `as int`처럼 직접 캐스팅하면 런타임 오류가 발생하기 때문에, 타입 통합 처리를 헬퍼에 위임했습니다.

**핵심 판단사항**

- **헬퍼 재사용**: API 숫자 필드가 `int` / `double` / `String("67,000")` 혼재 → 직접 캐스팅 시 런타임 오류 → `_readDouble` 등 헬퍼로 타입 통합 처리
- **`localDate` 정규화**: `_readLocalDate` 내부에서 `normalizeAsOfDate`로 시간 정보 제거 → 이후 `==` 날짜 비교 안전
- **`countOfListedStock` nullable**: API에서 항상 내려오지 않음 → `?? 0` fallback으로 시총 계산 null 오류 방지
- **`NaverHistoricalChartDto`**: 과제 요구사항에 따라 구현했으나, 현재 앱 흐름에서는 `fetchDailyHistoryPage` HTML 파싱 방식으로 대체되어 실제로 호출되지 않음

---

### 2. API Client (`naver_domestic_stock_client.dart`)

**어떻게 구현했는지**

4개 메서드를 구현했고, `fetchDailyHistoryPage`에 쓰이는 헬퍼 메서드를 추가했습니다.

- `_fetchDailyHistoryHtml`: HTTP 요청 + latin1 디코딩
- `_extractLastPage`: 페이지네이션에서 마지막 페이지 번호 추출
- `_parsePriceRows`: HTML에서 가격 행 전체 파싱
- `_extractCells`: 단일 `<tr>` 내 셀 텍스트 추출
- `_buildPriceDto`: 셀 배열을 DTO로 변환

하나에 요청/파싱/변환을 다 넣으니 코드가 길어져서, 단계를 명확하게 나눠 테스트 용이성과 가독성을 올렸습니다.

**핵심 판단사항**

- **`ResponseType.plain`**: body가 String으로 도착하는 경우가 있어 Dio 자동 디코딩 비활성화 → `_decodeJsonObjectBody`에서 타입별로 직접 처리 (`fetchRealtimeQuotes`도 동일)
- **`bytes + latin1` (HTML 파싱)**: 네이버 금융은 EUC-KR 인코딩 → `plain`으로 받으면 UTF-8 해석 오류 → raw bytes를 `latin1`으로 1:1 변환하면 날짜/숫자 파싱 정상
- **`areas.first`**: 국내 전용 단일 요청이므로 `areas`는 항상 1개 → `first`로 충분, Map으로 반환해 호출 측 O(1) 조회
- **HTML 행 필터링**: class/id 속성은 언제든 바뀔 수 있음 → `yyyy.MM.dd` 패턴 + `cells.length < 7` 이중 조건으로 데이터 행만 선별
- **`fetchDailyHistoryPage` 헬퍼 분리**: 요청/파싱/변환 단계를 독립 메서드로 분리 → 문제 발생 단계 즉시 파악 가능

---

### 3. Repository (`naver_watchlist_repository.dart`)

**어떻게 구현했는지**

4개 메서드를 구현하면서 헬퍼 메서드 3개를 추가했습니다.

- `_pickReferenceSymbol`: 거래일 기준 종목 선택
- `_fetchRemainingHistoryPages`: 나머지 페이지 배치 병렬 fetch
- `_loadRowsByDateForWindow`: 30거래일 윈도우에 해당하는 페이지 선별 로드

기존에 구현된 `_loadMetadataBatch`, `_loadRealtimeQuotes`, `_loadDailyHistoryPage`, `_loadHistoricalEntryForDate`, `_buildWatchlistItem`, `_resolveAsOf`, `_volumeRatio`, `_candles`, `_percentChange` 헬퍼를 최대한 활용했습니다.

**핵심 판단사항**

- **기준 종목 임의 선택**: 국내 종목 전체가 KRX 거래일 공유 → 첫 번째 유효 symbol을 기준으로 삼아도 결과 동일
- **1페이지 선순위 fetch**: `lastPage`를 먼저 알아야 나머지 배치 범위 결정 가능 → 1페이지 단독 fetch 후 나머지를 `Future.wait` 병렬 처리
- **과거 날짜에 realtime 미적용**: 실시간 데이터는 현재 시점 기준 → 과거 날짜에 쓰면 "현재가 ≠ 해당일 종가" 불일치 → 최신 거래일(`isLatest`)에만 적용
- **`latestDate`만 전달**: realtime/historical 판단 기준을 `_buildWatchlistItem` 시그니처에서 명확히 드러내기 위해 `availableDates` 전체 대신 필요한 값만 전달

---

### 4. SearchController (`search_controller.dart`)

**어떻게 구현했는지**

- `build()`: `ref.listen<AsyncValue<Set<String>>>(favoriteIdsControllerProvider, (prev, next) => _applyFavoriteIds(next.valueOrNull))`을 추가했습니다.
- `setQuery()`: 검색 결과 수신 직후 `ref.read(favoriteIdsControllerProvider).valueOrNull`로 현재 값을 읽어 `isFavorite`를 동기화했습니다.
- `toggleFavorite()`: toggle 완료 후 `_applyFavoriteIds(ref.read(favoriteIdsControllerProvider).valueOrNull)`로 결과를 즉시 갱신하고, `isAdded`가 true면 toast를, false면 `dismissToast()`를 호출했습니다.
- `_applyFavoriteIds()`: `state.results.requireValue`를 꺼내 각 아이템을 `copyWith(isFavorite: favoriteIds.contains(item.id))`로 재매핑하고, `selectedItemId`가 업데이트된 결과에 없으면 `null`로 해제했습니다.

**핵심 판단사항**

- **`ref.listen` 선택**: `ref.watch`는 `favoriteIdsControllerProvider` 변경 시 `build()` 전체 재실행 → `SearchUiState()` 초기화 → 검색어/결과/선택 상태 소실. `ref.listen`은 콜백만 호출하므로 기존 state를 보존하면서 `isFavorite`만 갱신 가능
- **첫 결과에 수동 동기화**: `ref.listen`은 provider가 변경될 때만 트리거 → 첫 검색 결과 수신 시점엔 `favoriteIdsControllerProvider` 상태가 바뀌지 않음 → `ref.read`로 직접 읽어 적용
- **`// ignore: unused_element` 스테일**: `_showToast`, `_applyFavoriteIds`에 달린 주석은 호출부가 없던 시점에 추가한 것 → 구현 완료 후 두 메서드 모두 호출되므로 제거 대상

---

### 5. SearchResultRow — RichText 하이라이트 + SearchActionBar

**어떻게 구현했는지**

- `_SearchTextColumn`: 기존 `Text` 2개를 `RichText` + `TextSpan` 리스트로 교체했습니다. `splitSearchTextParts(text, query)`로 일치 구간과 비일치 구간을 분리하고, 하이라이트 구간에만 `point_b980ff` 색상을 적용했습니다. subtitle의 `|` 구분선은 별도 `TextSpan`으로 분리해 `border_4_424242` 색상을 적용했습니다.
- `SearchActionBar`: 기존 플레이스홀더를 `SearchActionBar` 위젯으로 교체했습니다.

**핵심 판단사항**

- **`RichText` + `TextSpan`**: 쿼리 하이라이트를 인라인으로 처리 → `splitSearchTextParts`가 빈 query를 비하이라이트 파트로 반환하므로 `hasQuery` 분기 없이 단일 경로로 처리
- **subtitle `|` 구분선 분리**: figma 기준 구분선 색상이 본문 텍스트와 다름 → 별도 `TextSpan`으로 분리해 `border_4_424242` 색상 적용

---

### 6. SearchToast — BackdropFilter blur glass

**어떻게 구현했는지**

기존 단순 `Container`를 3계층 구조로 재구성했습니다.
  - `Container(shadow) > ClipRRect > BackdropFilter > Container(background/border)`
하트 + 체크 합성은 20×20 `SizedBox` 안에 `Stack`으로 구현했습니다.

**핵심 판단사항**

- **`ClipRRect > BackdropFilter` 계층 순서**: `ClipRRect` 없이 `BackdropFilter` 단독 사용 시 blur가 위젯 경계를 무시하고 사각형 전체에 적용 → `ClipRRect`로 렌더링 영역 제한해야 rounded corner blur 가능
- **`boxShadow` 외부 배치**: `ClipRRect` 내부에 shadow를 두면 clip에 잘려 glow 효과가 사라짐 → 외부 Container에서 shadow 담당, 내부 Container에서 blur/border 담당으로 역할 분리

---

### 7. WatchlistDateBottomSheet — 연/월/일 Wheel Picker

**어떻게 구현했는지**

기존 `SizedBox(Center(Text('TODO...')))` 블록을 주석 처리하고, `_DateWheelPicker` 위젯 3개를 `Expanded`로 감싼 Row로 교체했습니다. 파일 하단에 완성된 `_DateWheelPicker`와 상태 변수/핸들러들이 이미 있어서 연결만 했습니다.

**핵심 판단사항**

- **`_DateWheelPicker` 재사용**: 선택 스타일/탭 제스처/key 할당이 모두 구현 되어있어 연결만 하면 됨
- **`Expanded` 균등 분할**: figma 기준 세 컬럼 동일 비율 → 고정 너비 시 좁은 화면에서 오버플로우 위험

---

### 8. WatchlistScreen — 날짜 선택 후 동기화

**어떻게 구현했는지**

`_showDateBottomSheet`에서 기존 TODO 위치에 한 줄만 추가했습니다.

```dart
await ref.read(watchlistControllerProvider.notifier).setAsOf(normalizedDate);
```

초기에는 `setAsOf` 이후 `await _syncSelectedDetailWithSnapshot()`을 명시적으로 호출하는 식으로 작성하였는데, `ref.listen`이 이미 처리하고 있어서 제거했습니다.

**왜 그렇게 했는지**

`build()` 안에 아래 코드가 있습니다.

```dart
ref.listen<AsyncValue<WatchlistSnapshot>>(watchlistControllerProvider, (previous, next) {
  if (next.hasValue) {
    unawaited(_syncSelectedDetailWithSnapshot());
  }
});
```

`setAsOf`가 `watchlistControllerProvider` 상태를 갱신하면 이 `ref.listen`이 자동으로 `_syncSelectedDetailWithSnapshot()`을 호출합니다. `_showDateBottomSheet`에서 한 번 더 명시적으로 호출하면 동기화가 두 번 실행되어 불필요한 네트워크 요청이 발생합니다.

---

### 9. 바텀시트 SafeArea 구조 수정 (WatchlistSortBottomSheet / WatchlistDateBottomSheet)

**어떻게 구현했는지**

두 바텀시트 모두 기존의 `SafeArea(top:false) > Align > Container(color)` 구조를 `Align > Container(color) > SafeArea(top:false)`로 변경했습니다. `WatchlistSortBottomSheet`에서는 `Container`에 있던 `padding: EdgeInsets.only(bottom: 36)`도 제거했습니다(`SafeArea`가 bottom 간격을 처리하므로).

**왜 그렇게 했는지**

피그마 기준으로 UI를 구현하기 위한 선택이었습니다.

기존 구조에서는 `SafeArea`가 `Container` 외부에 있어서, home indicator 영역의 bottom inset이 `Container` 배경색이 아닌 투명 영역으로 남았습니다. 바텀시트 컨텐츠는 safe area 안에 들어오지만, home indicator 아래 배경이 시트 색상과 달라지는 문제가 있었습니다.
`Container`가 `SafeArea`를 감싸는 구조로 바꾸면, `Container`가 home indicator 영역까지 포함한 전체 높이를 차지하고 `SafeArea`는 컨텐츠 패딩만 담당하게 됩니다. 그 결과 시트 배경색이 home indicator 아래까지 자연스럽게 이어집니다.
