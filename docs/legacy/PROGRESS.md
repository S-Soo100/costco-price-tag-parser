# 진행 상황 (PROGRESS) — 코스트코 가격표 인식기

> 마지막 업데이트: 2026-06-09 · 설계 상세는 [기획서.md](기획서.md)

## 현재 상태

| # | 작업 | 상태 |
|---|------|------|
| 1 | OCR 실데이터 검증 + fixture (사진 46장) | ✅ |
| 2 | `PriceTagData` 파서 + 유닛테스트 | ✅ |
| 3 | 기획서 | ✅ |
| 4 | Flutter 스캐폴딩 (Riverpod / go_router / Mock / 역할 스위처) | ✅ |
| 5 | ML Kit 온디바이스 OCR 연결 (Android 빌드 검증 완료) | ✅ |
| 6 | 작업자 흐름 (캡처 → 비동기 OCR → 매대 요약) + OCR 디버그 | ✅ |
| 7 | **관리자 흐름** | ⬜ **다음 작업** |

**동작:** 역할 스위처 → (작업자) 매장 → 매대 → 가격표/제품 촬영 → 실시간 ML Kit OCR → `auto`/`review` → 매대 완료 → 달성률 갱신 / (관리자) 스켈레톤 / 🐞 OCR 테스트 디버그 화면.
**아직 Mock:** 백엔드 전부(`MockRepository`), 로그인(역할 스위처), 관리자 diff 데이터.

## 다음에 할 일 — ⑦ 관리자 흐름
`lib/features/admin/admin_home_screen.dart` 는 현재 스켈레톤(5섹션 placeholder). 구현 목표:
- 매장별 **금주(달력주 월~일)** diff: `신규 품목 / 신규 할인 / 삭제 품목 / 금주 현황`
- **검수·입력 대기**: OCR `review`·B포맷(제품 라벨) → 사진 보고 수동 입력
- 개발 단계는 **mock diff 데이터**로 화면 완성 (`Repository`에 mock diff 메서드 추가 → `MockRepository` 구현)

후속(그 이후): 파서 ML Kit 튜닝(필요 시), 실 백엔드 `ApiRepository`로 교체, 실 인증, (선택) 라이브 카메라 프리뷰, B포맷 파서.

## 빠른 재개
```bash
flutter run                     # 실기기 / Android 에뮬 (※ iOS 시뮬은 ML Kit 미지원)
flutter test                    # 7개 통과 (파서4 + 캡처2 + 위젯1)
flutter analyze                 # clean
flutter build apk --debug       # ML Kit 통합 빌드 검증
dart tools/parser_check.dart    # 데스크톱 파서 회귀 체크 (Vision fixture 기준)
```
- 메인 화면 **🐞 OCR 테스트 (디버그 전용)** → 사진 선택 → 파싱 결과 + OCR 원문(줄/위치) 확인, "결과 복사"로 공유
- 작업자 캡처 화면: 캡처 타일 **🐞 N줄** 탭 → rawText 바텀시트, 콘솔에 `[OCR] cap_N → auto …` 실시간 로그

## ⚠ 핵심 주의 (건드리면 깨짐)
- **ML Kit 한국어 모델**: `android/app/build.gradle.kts` 의 `implementation("com.google.mlkit:text-recognition-korean:16.0.1")` — 플러그인이 `compileOnly`로만 선언하므로 앱이 직접 추가해야 함. 지우면 런타임 `ClassNotFoundException: KoreanTextRecognizerOptions`.
- **iOS 시뮬레이터**: ML Kit 텍스트 인식 미지원 + 카메라 없음 → **실기기 또는 Android 에뮬**에서 테스트.
- **번들ID** `com.example.costcoPriceTagRecognizer` 는 **임시** → iOS 실기기 서명 시 고유 ID로 변경 필요. (iOS 15.5+, Android minSdk 21)
- **파서는 데스크톱 Vision 출력 기준으로 튜닝됨.** ML Kit는 줄 분할이 다를 수 있어 오인식 시 OCR 디버그 화면의 rawText를 보고 `lib/core/ocr/price_tag_parser.dart` 보정.

## OCR 파이프라인 구조
- `OcrEngine`(인터페이스) ← `MlKitOcrEngine`(실기기, 기본) · `MockOcrEngine`(번들 fixture, 카메라 없이 dev용) · 테스트는 `FakeOcr` 오버라이드
- `parsePriceTag(List<OcrLine>) → PriceTagData` : 순수 Dart, 엔진 무관 (Vision·ML Kit 동일 입력)
- 개발 하네스: `tools/vision_ocr.swift`(macOS Vision으로 `sample_tags/` OCR) → `tools/ocr_raw.json`(fixture) → `tools/parser_check.dart`(파서 자가검증) / `assets/ocr_fixtures.json`(MockOcrEngine용)

## 구조 (lib)
```
lib/
  main.dart · app.dart
  core/ocr/    price_tag_data · price_tag_parser · ocr_engine · mlkit_ocr_engine · mock_ocr_engine
  core/router/ app_router
  data/        models · repository · mock_repository · providers
  features/auth/    role_switcher_screen
  features/worker/  store_list_screen · rack_list_screen · rack_capture_screen · capture_session
  features/admin/   admin_home_screen        ← ⑦ 여기 구현
  features/debug/   ocr_test_screen
test/   price_tag_parser_test · capture_session_test · widget_test
tools/  vision_ocr.swift · parser_check.dart · ocr_raw.json
sample_tags/  실사진 46장 · assets/ocr_fixtures.json
```
