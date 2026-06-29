# costco-price-tag-parser

한국어 · **[English](README.md)**

[![conformance](https://github.com/S-Soo100/costco-price-tag-parser/actions/workflows/conformance.yml/badge.svg)](https://github.com/S-Soo100/costco-price-tag-parser/actions/workflows/conformance.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-pure%20%C2%B7%200%20deps-0175C2.svg)](packages/dart)
[![Python](https://img.shields.io/badge/Python-3.10%2B%20%C2%B7%200%20deps-3776AB.svg)](packages/python)
[![TypeScript](https://img.shields.io/badge/TypeScript-ESM%2BCJS%20%C2%B7%200%20deps-3178C6.svg)](packages/typescript)

**코스트코 가격표**의 OCR 텍스트를 구조화된 데이터로 변환합니다 — **Dart · Python · TypeScript** 세 언어로.

```
[사진] ──(OCR: 자유 선택)──▶ OcrLine[] ──(이 라이브러리)──▶ PriceTagData
        ML Kit / Tesseract / Vision …      순수 로직, 3개 언어에서 동일
```

> **한국 코스트코 전용입니다.** 한국 코스트코 매장의 **A포맷 매대카드**(품목번호 + `원` 가격 + `할인행사`/`단가` 라벨)와 **한국어 OCR**을 전제로 휴리스틱이 튜닝돼 있습니다. 다른 나라 코스트코나 일반 가격표에는 맞지 않습니다.

가격표에서 어려운 부분은 OCR이 아니라, 인식된 텍스트 박스 더미를 *"품목 685246, ₩349,900, 정가 ₩389,900에서 할인"* 으로 **해석**하는 일입니다. 그 해석 로직이 여기 있고, 세 언어로 포팅돼 **공유 골든 적합성 스위트**(CI에서 매번 검증)로 **동작이 동일하게(같은 입력 → 같은 구조화 출력)** 유지됩니다.

> **OCR은 직접 고르세요(BYO-OCR).** 코어는 **런타임 의존성 0**입니다. 어떤 엔진의 결과든 `OcrLine` 형태로만 넣으면 됩니다 — Google ML Kit, Tesseract, Apple Vision, 클라우드 API 등. 언어별 *선택형* 참조 어댑터는 [`examples/`](examples)에 있습니다.

---

## 목차

- [왜 만들었나](#왜-만들었나)
- [설치](#설치)
- [빠른 시작](#빠른-시작)
- [입력 — `OcrLine`](#입력--ocrline)
- [출력 — `PriceTagData`](#출력--pricetagdata)
- [OCR은 직접 연결](#ocr은-직접-연결)
- [3언어 동작 일치는 어떻게 보장하나](#3언어-동작-일치는-어떻게-보장하나)
- [알려진 한계](#알려진-한계)
- [저장소 구조](#저장소-구조)
- [개발](#개발)
- [기여](#기여)
- [라이선스](#라이선스)

## 왜 만들었나

OCR 엔진은 텍스트와 바운딩 박스를 줄 뿐입니다. 어떤 숫자가 가격인지, 어떤 게 단가인지, 할인 중인지, 6자리 품목번호가 어디 있는지는 알려주지 않습니다. 코스트코의 표준 "A포맷" 매대카드에는 일관된 시각 문법이 있습니다 — 최종가는 글자가 가장 크고, 품목번호는 한 줄에 단독으로 있으며, `할인행사` 라벨이 할인을 표시합니다. 이 라이브러리는 그 문법을 작고 의존성 없는 휴리스틱 파서로 인코딩했습니다.

이 로직을 언어마다 따로 짜면 점점 어긋납니다. 그래서 여기서는 **Dart 구현이 정본(canonical)**이고, 그 출력을 골든 오라클로 동결한 뒤 Python·TypeScript 포트를 *같은* 오라클로 검증합니다 — 셋이 항상 발맞춥니다. [동작 일치 보장](#3언어-동작-일치는-어떻게-보장하나) 참고.

## 설치

> ⚠️ **아직 레지스트리에 미발행** (pub.dev / PyPI / npm — [ROADMAP](ROADMAP.md)에서 추적). 그전까지는 [소스에서 설치](#소스에서-설치)를 쓰세요. 아래 명령은 발행 후의 사용법입니다.

| 언어 | 발행 후 |
|------|---------|
| Dart / Flutter | `dart pub add costco_price_tag_parser` |
| Python | `pip install costco-price-tag-parser` |
| TypeScript | `npm install costco-price-tag-parser` |

### 소스에서 설치

**Python** (지금 가능):
```bash
pip install "git+https://github.com/S-Soo100/costco-price-tag-parser.git#subdirectory=packages/python"
```

**Dart** — `pubspec.yaml`에 git 의존성 추가:
```yaml
dependencies:
  costco_price_tag_parser:
    git:
      url: https://github.com/S-Soo100/costco-price-tag-parser.git
      path: packages/dart
```

**TypeScript** — 클론 후 로컬 참조:
```bash
git clone https://github.com/S-Soo100/costco-price-tag-parser.git
cd costco-price-tag-parser/packages/typescript && npm install && npm run build
# 그런 다음 내 프로젝트에서:
npm install /절대경로/costco-price-tag-parser/packages/typescript
```

## 빠른 시작

당신이 제공할 것은 `OcrLine` 리스트 하나뿐입니다 ([계약](#입력--ocrline) 참고).

**Dart**
```dart
import 'package:costco_price_tag_parser/costco_price_tag_parser.dart';

final lines = await myOcr.recognize(imagePath); // List<OcrLine>
final tag = parsePriceTag(lines);

print(tag.itemNumber); // "685246"
print(tag.finalPrice); // 349900
print(tag.toJson());   // JSON용 Map
```

**Python**
```python
from costco_price_tag_parser import parse_price_tag, OcrLine

lines = [OcrLine.from_json(e) for e in my_ocr_output]
tag = parse_price_tag(lines)

print(tag.item_number)   # "685246"
print(tag.final_price)   # 349900
print(tag.to_dict())     # camelCase 키 dict
```

**TypeScript**
```ts
import { parsePriceTag, type OcrLine } from "costco-price-tag-parser";

const lines: OcrLine[] = myOcrOutput;
const tag = parsePriceTag(lines);

tag.itemNumber;       // "685246"
tag.finalPrice;       // 349900
JSON.stringify(tag);  // 이미 표준 스키마 형태
```

## 입력 — `OcrLine`

정규화된 바운딩 박스를 가진 텍스트 줄들의 **순서 있는** 리스트입니다.
스키마: [`spec/schema/ocr_line.schema.json`](spec/schema/ocr_line.schema.json).

| 필드 | 타입 | 의미 |
|------|------|------|
| `text` | string | 인식된 줄 텍스트 |
| `x` | number | 왼쪽 끝, `0..1` 정규화 |
| `yTop` | number | 위쪽 끝, `0..1` 정규화 (**원점 좌상단**, `0` = 이미지 맨 위) |
| `w` | number | 너비, `0..1` 정규화 |
| `h` | number | 높이, `0..1` 정규화 — **글자 높이 대용**(최종가가 가장 크게 인쇄됨) |
| `conf` | number | OCR 신뢰도 `0..1` (파서는 안 씀, 호출자 편의로 전달) |

요구사항:
- `0..1`로 **정규화**, 원점 **좌상단**.
- **읽기 순서**: 위→아래, 그다음 왼쪽→오른쪽.
- 단어 단위가 아니라 **줄 단위** 1개씩. 대부분 엔진이 줄로 묶어 주며, 그렇지 않으면 [`examples/python_tesseract`](examples/python_tesseract)에 단어 박스를 줄로 묶는 예시가 있습니다.

(Python은 동일 camelCase 키로 `OcrLine.from_json({...})`, 또는 생성자 `OcrLine(text, x, y_top, w, h, conf)`.)

## 출력 — `PriceTagData`

스키마: [`spec/schema/price_tag_data.schema.json`](spec/schema/price_tag_data.schema.json).
JSON 키는 세 언어 모두 camelCase입니다.

| 필드 | 타입 | 비고 |
|------|------|------|
| `schemaVersion` | string | 항상 `"0.1"` |
| `itemNumber` | string \| null | 6자리 품목번호 — 매장 공통 추적 키 |
| `plusMark` | boolean | 품목번호 뒤 `+` (의미 미상, 원문 보존) |
| `finalPrice` | int \| null | 최종가(원) — 물리적으로 가장 큰 가격 토큰 |
| `tagType` | `"regular"` \| `"discount"` \| `"unknown"` | 품목번호·가격이 **둘 다** 없을 때만 `unknown` |
| `discount` | object \| null | `tagType == "discount"`일 때만 존재 |
| `discount.originalPrice` | int \| null | 할인 전 정가 |
| `discount.discountAmount` | int \| null | `정가 − 최종가` |
| `discount.periodStart` / `periodEnd` | string \| null | ISO 날짜, **best-effort** ([한계](#알려진-한계) 참고) |
| `unitPrice` | object \| null | `단가 / <단위>` 라벨에서 추출한 `{ value, unit }` |
| `nameEn` | string \| null | 영문 제품명(best-effort) |
| `nameKo` / `model` | string \| null | **예약** — 아직 미추출(항상 null) |
| `rawText` | string | OCR 전체 텍스트(줄을 `\n`으로 연결), 재파싱·검수용으로 항상 보존 |

예시 (`IMG_3374`, 할인 중인 로봇청소기):

```jsonc
{
  "schemaVersion": "0.1",
  "itemNumber": "685246",
  "plusMark": true,
  "nameKo": null,
  "model": null,
  "nameEn": "ROBOROCK AQUA VACUUM",
  "finalPrice": 349900,
  "tagType": "discount",
  "discount": {
    "originalPrice": 389900,
    "discountAmount": 40000,
    "periodStart": "2026-05-12",
    "periodEnd": "2026-06-07"
  },
  "unitPrice": null,
  "rawText": "…OCR 전체 텍스트…"
}
```

정규식과 동점 처리까지 포함한 정확한 알고리즘은 [`spec/SPEC.md`](spec/SPEC.md)에 언어 중립으로 명세돼 있습니다.

## OCR은 직접 연결

파서는 이미지를 절대 건드리지 않고 `OcrLine`만 받습니다. 각 패키지는 어댑터를 통일하기 위한 선택형 `OcrEngine` 인터페이스를 정의합니다:

```dart
abstract class OcrEngine {            // Dart
  Future<List<OcrLine>> recognize(String imagePath);
}
```
```python
class OcrEngine(Protocol):            # Python
    def recognize(self, image_path: str) -> list[OcrLine]: ...
```
```ts
interface OcrEngine {                 // TypeScript
  recognize(imagePath: string): Promise<OcrLine[]>;
}
```

참조 어댑터(각각 **선택사항**)는 [`examples/`](examples)에 있습니다:

| 예제 | OCR 엔진 | 실행 환경 |
|------|---------|-----------|
| [`flutter_camera_demo`](examples/flutter_camera_demo) | Google ML Kit (온디바이스) | 실기기 iOS/Android 또는 Android 에뮬 (iOS 시뮬 불가) |
| [`python_tesseract`](examples/python_tesseract) | Tesseract (시스템 바이너리) | 데스크톱/서버 |
| [`ts_tesseract`](examples/ts_tesseract) | tesseract.js (WASM) | Node.js, 시스템 바이너리 불필요 |

> OCR 환경이 없나요? macOS라면 [`tools/vision_ocr.swift`](tools/vision_ocr.swift)가 Apple Vision으로 동일한 `OcrLine` JSON을 만들어 줍니다.

## 3언어 동작 일치는 어떻게 보장하나

세 구현을 일치시키는 핵심은 단 하나의 공유 오라클입니다:

1. **정본 Dart 파서**를 **실사진 46장 픽스처**([`spec/fixtures/ocr_raw.json`](spec/fixtures))에 돌려 그 출력을 [`spec/golden/expected.json`](spec/golden)으로 동결합니다.
2. 모든 언어의 적합성 스위트가 **같은** 픽스처를 파싱해 **같은** 골든과 대조합니다.
3. **CI**([`conformance.yml`](.github/workflows/conformance.yml))가 push·PR마다 세 스위트를 모두 돌립니다.

두 종류의 보장 (전체 정책은 [`spec/CONFORMANCE.md`](spec/CONFORMANCE.md)):

- **Ground truth** — 3장(`IMG_3374`, `IMG_3379`, `IMG_3383`)은 실제 태그와 사람이 대조 검증함. **실세계 정확성**을 단언.
- **Golden parity** — 나머지 43장은 정확성이 아니라 *동작*을 고정. 골든과 일치 = Dart와 동일함이 증명될 뿐.

픽스처가 모든 분기를 다루지 못하므로, [코드 리뷰](docs/cross-review-2026-06.md)가 드러낸 언어 간 위험 지점을 겨냥한 **합성 "패리티 트랩" 테스트**도 포함합니다 — 예: 가격 안의 비-ASCII 공백(NBSP), `yTop`이 같은 두 품목번호 후보(`x` 동점 처리로 결정론적 선택). 포팅 시 주의점(ASCII 숫자, 코드포인트 반복, 정렬 결정성)은 [`spec/SPEC.md`](spec/SPEC.md)에 있습니다.

현재 테스트: **Dart 55 · Python 101 (55 + 스키마 검증 46) · TypeScript 55**.

## 알려진 한계

이 파서는 표준 A포맷 매대카드에 맞춘 **휴리스틱**이지 검증기가 아닙니다. 여러 가드가 들어가 있지만([`spec/SPEC.md`](spec/SPEC.md)), 핵심 한계는 남아 있습니다:

- **비-A포맷 태그를 감지하지 못합니다.** 베이커리 라벨·영수증·풍경샷은, 그럴듯한 품목번호나 `…원` 가격이 하나라도 잡히면 `unknown`이 아니라 `regular`로 나옵니다. 핫라인 번호(`139원`) 같은 잡토큰이 가격으로 잡힐 수 있습니다. 제대로 된 비-A포맷 감지는 주요 미해결 과제입니다 — [ROADMAP item 4](ROADMAP.md) 참고.
- **품목번호가 7자리 이상으로 OCR되면 `null`이 됩니다.** 숫자 경계 가드가 바코드의 6자리 부분은 올바르게 거부하지만, OCR이 숫자를 하나 더 붙인 진짜 품목번호(`1819440`)도 거절합니다 — 추측 대신 `null`.
- **날짜는 best-effort입니다.** 달력상 불가능한 날짜는 이제 버리지만(연 2000–2099·월 1–12·일 1–31), OCR이 *그럴듯하지만 틀린* 날짜를 줄 수 있어 `periodStart`/`periodEnd`는 참고용으로만 보세요.

이미 가드된 것: 영양/무게 수치(`2,142kcal`, `1,584g`)는 더 이상 가격으로 오인하지 않음, 불가능 날짜는 제거됨, 6자리 바코드 부분 문자열은 거부됨.

신뢰도 낮은 출력은 *"사람 검수 필요"* 로 다루는 걸 권장합니다.

## 저장소 구조

```
spec/         SPEC.md · schema/ · fixtures/ · golden/ · CONFORMANCE.md   ← 단일 진실 원천
packages/
  dart/       pub.dev 패키지 · 정본 · 순수 Dart (Flutter 비의존)
  python/     PyPI 패키지 · src 레이아웃 · 타입 제공 (py.typed)
  typescript/ npm 패키지 · ESM + CJS + d.ts
examples/     flutter_camera_demo · python_tesseract · ts_tesseract       ← 선택형 OCR 어댑터
tools/        vision_ocr.swift                                            ← 픽스처 생성기 (Apple Vision)
docs/         cross-review-2026-06.md · legacy/ (원래 Flutter 앱 스펙)
```

실사진 46장은 클론을 가볍게 유지하려고 **저장소에 두지 않습니다** — [`fixtures-source` 릴리스](https://github.com/S-Soo100/costco-price-tag-parser/releases/tag/fixtures-source)에 있습니다.

## 개발

각 패키지는 독립적이며 저장소 루트를 거슬러 올라가 `spec/`을 찾으므로 어느 위치에서 실행해도 동작합니다.

| | 세팅 | 테스트 | 린트 / 타입 |
|-|------|--------|-------------|
| **Dart** | `cd packages/dart && dart pub get` | `dart test` | `dart analyze` |
| **Python** | `cd packages/python && python -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]"` | `pytest` | `mypy src && ruff check .` |
| **TypeScript** | `cd packages/typescript && npm install` | `npm test` | `npm run typecheck` · `npm run build` |

정본(Dart)을 바꾼 뒤에는 골든을 재생성하세요:

```bash
cd packages/dart && dart run tool/gen_golden.dart
```

## 기여

[CONTRIBUTING.md](CONTRIBUTING.md) 참고. 한 가지 규칙: **`packages/dart`를 먼저 고치고 → 골든 재생성 → Python·TypeScript를 맞춘다 → 세 스위트 모두 green.** `spec/golden/expected.json`은 생성물이므로 절대 손으로 고치지 마세요.

## 라이선스

[MIT](LICENSE).
