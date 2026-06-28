# 코스트코 가격표 인식기 → 3언어 오픈 라이브러리 전환 계획

> 작성: 2026-06-28 · 기존 Flutter 앱(`기획서.md`/`PROGRESS.md`)에서 **순수 파서 라이브러리 + 적합성 테스트 스위트**로 전환.
> 상태: 승인 완료, 오토모드 실행 중.

---

## 0. 무엇을 만드는가

코스트코 A포맷 가격표의 OCR 결과(`OcrLine[]`)를 구조화 데이터(`PriceTagData`)로 파싱하는 **휴리스틱 파서**를, **Flutter(Dart) · TypeScript · Python** 3개 언어에서 동일하게 쓸 수 있는 오픈소스 라이브러리로 제공한다.

핵심은 "앱"이 아니라 **"파서 + 언어 간 동작 일치(parity)를 보장하는 적합성 스위트(conformance suite)"**.

## 1. 확정된 결정

| # | 결정 | 선택 |
|---|------|------|
| 1 | 레포 구조 | **모노레포 1개** — `spec/` + `packages/{dart,python,typescript}` + `examples/` |
| 2 | OCR 범위 | **하이브리드** — 파서 코어(의존성 0)가 제품, OCR은 인터페이스 + 언어별 reference 어댑터를 `examples/`로만 |
| 3 | 기존 Flutter 앱 | **축소 데모로 보존** — `examples/flutter_camera_demo` (카메라→ML Kit→파서→표시). 관리자·api·mock은 폐기 |

## 2. 핵심 통찰 — 기술은 2개 층, 포팅 대상은 1개

```
[이미지] ──(Layer A: OCR)──▶ OcrLine[] ──(Layer B: 파서)──▶ PriceTagData
          플랫폼 종속·이식 불가          순수 로직·완전 이식 가능
          ML Kit / Tesseract / Vision     ← 이 ~145줄이 진짜 제품
```

- **Layer B(파서)만** 3언어로 포팅한다. OCR(Layer A)은 언어/플랫폼마다 다른 상용 부품이라 인터페이스만 맞춘다.
- 두 층을 잇는 **계약은 이미 JSON**이다 (`OcrLine` in, `PriceTagData` out). 이걸 언어중립 스펙(JSON Schema) + 골든 픽스처로 한 번 정의하면, 세 언어가 같은 입력에 같은 출력을 내는지 자동 검증된다 → **패리티가 공짜로 보장**.

## 3. 골든 오라클 전략

- 정본 **Dart 파서**를 46장 픽스처에 돌려 `spec/golden/expected.json`을 **동결** → 이것이 오라클.
- 각 언어 패키지는 `spec/`을 읽어 "내 출력 == golden" 적합성 테스트를 **CI 게이트**로 둔다.
- **정직성 명시:** 46장 중 **3장(IMG_3374/3379/3383)만 사람이 검증한 ground-truth**, 나머지 43장은 *Dart 기준 parity-lock*. Dart 오류 발견 시 → Dart 수정 → golden 재생성 → 3언어 재동기화. 이 정책은 `spec/CONFORMANCE.md`에 기록.

## 4. 목표 구조

```
costco-price-tag-parser/
  LICENSE (MIT) · README.md · CONTRIBUTING.md · PLAN.md
  .github/workflows/conformance.yml      # 3-job 매트릭스
  spec/                                   # 단일 진실원천
    SPEC.md                               # 휴리스틱 언어중립 산문 + 규칙표
    schema/ ocr_line.schema.json · price_tag_data.schema.json
    fixtures/ ocr_raw.json                # 46장 입력
    golden/ expected.json                 # Dart 정본 기대출력 (오라클)
    CONFORMANCE.md
  packages/
    dart/        # pub.dev · 정본 · 순수 Dart(Flutter 의존 X)
    python/      # PyPI · costco_price_tag_parser
    typescript/  # npm · costco-price-tag-parser (ESM+CJS)
  tools/  vision_ocr.swift                # 픽스처 생성기
  examples/ flutter_camera_demo/ python_tesseract/ ts_tesseract/
  sample_tags/                            # 실사진 46장
```

## 5. 단계별 로드맵

| Phase | 목표 | 완료 게이트 |
|-------|------|------------|
| **0. 철거 & 골격** | 앱 껍데기 폐기 + 모노레포 골격 + git init | dart 패키지에 파서 코어만 남고 빌드 clean |
| **1. 스펙 동결** | 계약 언어중립화 + 골든 오라클 | golden이 Dart에서 결정론적으로 재생성됨 |
| **2. Dart 정본화** | Flutter 떼고 순수 Dart 패키지 | `dart test`(파서+적합성) green, `dart analyze` clean |
| **3. Python 포트** | PyPI 패키지 | 46장 적합성 green |
| **4. TypeScript 포트** | npm 패키지 | 46장 적합성 green, `tsc --strict` clean |
| **5. Reference OCR 예제** | 사진→결과 1개씩 | 각 예제 end-to-end(가능 범위) |
| **6. 오픈소스 마감** | 공개 준비 | CI 3언어 green, README/CONTRIBUTING/LICENSE |

## 6. 포팅 함정 (순진하게 옮기면 패리티 깨짐)

| 함정 | Dart 원본 | Python/TS 주의 |
|------|-----------|----------------|
| 코드포인트 반복 | `t.runes` | JS `[...t]` (←`t.length`는 UTF-16). Python은 안전 |
| 정규식 `\d` | ASCII | Python `re.ASCII` 고정. JS `\d`는 ASCII |
| 정렬 안정성 | `List.sort`(불안정) | yTop 동률 시 `x` 보조 키로 3언어 통일 |
| `nameKo`/`model` | 파서가 안 채움(null) | SPEC에 "reserved, 미추출" 명시 |

## 7. 리스크 / 미결

- ML Kit 한국어 의존성·iOS 시뮬 미지원 → Flutter 예제에만 격리(코어 무관).
- tesseract 바이너리 미설치 → Python/TS OCR 예제는 코드 제공·로컬 실행 검증 제한(macOS Vision swift 경로는 가능).
- 패키지명/네임스페이스·퍼블리시 계정(pub/PyPI/npm) → 퍼블리시 시 확정.
