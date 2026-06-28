# 교차 검수 결과 (Codex + Claude)

> 2026-06-28 · 대상: 3언어 파서 모노레포(spec/ + packages/{dart,python,typescript} + README/PLAN)
> 이종 2모델 정상 가동(폴백 없음). Codex=자유 검수, Claude 서브에이전트=4렌즈(새 컨텍스트).

## 요약
- **Codex 24건, Claude 13건 / 공통 핵심 7건.** 두 모델이 독립적으로 **정렬 비결정성**과 **Python 정규식 분기**를 최상위로 지목 → 신뢰도 높음.
- 한 줄 결론: 코어 설계·3언어 모델 일관성은 견고하나, **적합성 스위트가 "trap-free 46장"에서만 녹색이라 거짓 확신을 준다.** 잠재 패리티 분기 3건이 정확히 미테스트 입력에서 터지고, 골든이 일부 명백한 오인식을 "정답"처럼 고정.

---

## 🔴 2모델 공통 — 수정 권장

### C1. 정렬 비결정성 — 오라클 자체가 흔들릴 수 있음 (둘 다 #1)
- `price_tag_parser.dart:23,30` `..sort((a,b)=>a.yTop.compareTo(b.yTop))` 보조키 없음. Dart `List.sort`는 **stable 보장 없음**인데 `spec/SPEC.md:48,94`는 stable 요구, `PLAN.md:78`은 **`x` 보조키 통일을 처방했으나 미적용**.
- 실데이터 동률 존재: `IMG_8393.HEIC`에 pure-item 후보 `694093`/`692370`이 **동일 yTop=0.36** (Codex: `ocr_raw.json:5920`, Claude 스크립트 확인). 지금은 Dart가 작은 리스트에 안정 삽입정렬을 써 우연히 Python/JS와 일치하나, **큰 입력(픽스처 최대 114줄)에서 후보가 임계치를 넘으면 정본 출력이 비결정적** → 골든 신뢰성까지 붕괴.
- **수정:** 3언어+SPEC 모두 정렬키를 `(yTop, x)` 또는 입력 인덱스 보조로 통일 → `dart run tool/gen_golden.dart` 재생성 → 3 적합성 재확인.

### C2. Python `_PRICE`의 `re.ASCII`가 `\s`까지 ASCII로 묶어 분기 (둘 다)
- `parser.py:15` `re.compile(r"(\d[\d,]{2,})\s*원", re.ASCII)` — `re.ASCII`는 `\d`뿐 아니라 **`\s`도 ASCII 공백 한정**. Dart/JS(`price_tag_parser.dart:133`, `parser.ts:10`)의 `\s`는 유니코드 공백 포함. `"23890　원"`(콤마 없는 가격+전각공백)이면 Dart/JS는 토큰 생성, Python은 불발 → finalPrice/tagType 갈림. (`_UNIT`은 의도적으로 `re.ASCII`를 뺐는데 `_PRICE`에서 놓침.)
- **수정:** Python의 숫자 패턴에서 `\d`→`[0-9]`로 명시하고 `re.ASCII` 제거(→`\s` 유니코드 유지). `_PURE_ITEM/_ITEM/_PRICE/_COMMA_NUM/_DATE` 동일 적용.

### C3. 골든이 명백한 비-A포맷 오인식을 "정답"으로 고정 (Codex 구체 / Claude "거짓 확신")
- `expected.json`: `IMG_8407` → `nameEn:"Tel. 1899-9900"`, `finalPrice:139`(신고전화) · `IMG_8408` → `2142`(2,142kcal) · `IMG_8409` → `1584`(1,584g)를 가격으로 고정. 불가능 날짜도 고정: `6106-01-04`, `2026-00-05`, `2026-06-70`(`expected.json:106,186`).
- 근본: `_priceRe`/`_itemRe`/`_dateRe`가 **문맥·경계 없이** 숫자를 잡음(`price_tag_parser.dart:131,133`). parity-lock은 "동작 동일"만 보장하고 **정확성은 보장 안 함**(CONFORMANCE.md가 공시하긴 함). 단, 잠재버그 위치 = 미테스트 입력이라 스위트가 못 잡음.
- **수정:** (작게) README 과장 수정(C4) + 한계를 명시. (크게/후속) 경계·문맥 가드(예: `139원`은 본문 전화, kcal/g 뒤 숫자 배제) 추가 → 골든 재생성. 트랩 겨냥 픽스처/유닛테스트 추가.

### C4. README 과장 2건 (둘 다)
- `README.md:12` "byte-for-byte identical" — 실제는 `rawText` 제외 **구조화 객체 동치**(바이트 동일 아님).
- `README.md:77` "Non-A-format tags degrade to unknown" — **골든에 unknown 0건**. 파서는 item·price 중 **하나만 있어도 regular**로 판정(`price_tag_parser.dart:61-65`). 주장과 코드가 모순.
- **수정:** 두 문장 정확히 수정.

### C5. JSON 스키마가 어디서도 검증에 안 쓰임 (둘 다)
- validator 0건(py deps `[]`, npm에 ajv 없음). conformance는 골든 dict만 비교(`test_conformance.py:66`)라 스키마-코드-골든 drift를 못 잡음. 스키마가 사실상 죽은 문서.
- **수정:** 적합성에 경량 스키마 검증 1패스 추가(py `jsonschema`, ts `ajv`) **또는** README/spec에 "참고용 문서"로 명시.

### C6. SPEC "remove all spaces" vs 구현 "ASCII 스페이스만" (Codex SPEC:46, Claude 관련)
- `spec/SPEC.md:46`는 "모든 공백 제거"지만 3구현 모두 `' '`(U+0020)만 제거 → tab/NBSP/전각공백 입력에서 스펙 해석과 달라짐.
- **수정:** SPEC을 "ASCII space(U+0020) 제거"로 코드에 맞춰 정정(파리티 안전).

### C7. ground-truth 3장이 일부 필드만 assert (둘 다)
- `conformance_test.dart:27` 등 — 기간·`nameEn`·`unit`·`rawText`·스키마 적합성은 사람 검증 0. (43장 parity-lock과 합치면 "사람이 본" 범위가 좁음.)
- **수정:** 3장의 검증 필드 확장(기간·단위 포함).

---

## 🟡 단독 지적 — 채택/기각 판단

| 출처 | 지적 | 판단 |
|------|------|------|
| Claude | `nameEn` 길이 게이트: Dart `t.length`(UTF-16) vs 포트 코드포인트(`parser.py:117`/`parser.ts:120`). 비-BMP 문자 경계서 분기 | **채택** — 잠재 분기. SPEC §7이 길이 단위 미명시. 셋 다 코드포인트로 통일 or 정본 UTF-16에 맞춤 |
| Codex | `pyproject:16` `Typing::Typed`인데 `py.typed` 마커 없음 → 배포 시 타입 미인식 | **채택** — 실 패키징 버그. `py.typed` 빈 파일 추가 |
| Codex | `pyproject:10` `requires-python>=3.9`인데 `str\|None` 사용 | **채택(주의)** — `from __future__ import annotations`로 3.9도 될 가능성 있으나 미검증. **>=3.10으로 상향**(안전) 또는 CI에 3.9 추가 |
| Codex | `discount` 객체가 `tagType=unknown`(할인행사만 있고 item/price 없음)일 때도 생성 → 스키마 설명과 충돌(`parser.dart:67`) | **채택** — `tagType==discount`일 때만 discount 생성하도록 가드. 소수정 |
| Codex | `unitPrice`가 finalTok과 **같은 v·h를 가진 모든 토큰** skip(`parser.dart:101`) → 동값·동높이 중복 시 합법 단가 제거 | **채택(저순위)** — latent 엣지. 인덱스 동일성으로 skip하도록 정밀화 검토 |
| Codex | `nameEn`이 ASCII비율만 봐 `Tel.`/`Item: #512905`를 영문명으로 | **채택** — C3 가족(휴리스틱 순진). 후속 하드닝 |
| Codex | item regex 경계 없음 → `2606833하`→`260683` 바코드 흡수 | **채택(후속)** — 경계 가드는 골든 파급 큼. 한계로 기록 후 별도 처리 |
| Codex | `CONFORMANCE.md:14` "without rawText"인데 스키마는 rawText required → 골든용 별도 스키마 필요 | **채택(문서)** — 골든은 PriceTagData의 subset임을 스키마/문서로 분리 |
| Codex | TS README "ships ESM+CJS+types"인데 CI가 build 미검증(`conformance.yml:49`) | **채택** — CI(로컬 hook 무관)에 `npm run build` 잡 추가 |
| Codex | TS `number`로 2^53 초과 정수 분기, 스키마 상한 없음(`parser.ts:53`) | **기각** — 가격이 9×10^15원 초과 불가. 실현 불가. (원하면 스키마에 max만 표기) |
| Codex | 스키마 "required signal=itemNumber+finalPrice" vs SPEC "둘 다 null만 unknown" 모순 | **채택(문서)** — 스키마 설명을 SPEC에 맞춰 정정 |
| Claude | Dart `_canon`(conformance_test:74) 키순서 무관 비교가 다소 과함 | **기각** — 무해·견고성 +. 유지 |

---

## 💡 직관 질문 답변

- **없애도 되는 것:** 현 JSON 스키마는 **죽은 문서**(검증기 미연결). 살리거나(테스트 1패스) "참고용"이라 명시. 3언어 구조 자체는 제품 본질이라 제거 대상 아님.
- **최대 리스크 하나:** **적합성 스위트의 거짓 확신.** "3언어 동일"을 보장한다지만 패리티 분기 3건(C1 정렬·C2 `\s`·nameEn 길이)은 *어떤 픽스처도 안 밟는 입력*에서만 터지고, 골든은 일부 오인식을 정답처럼 고정. 증명의 사각 = 잠재버그 위치.
- **공개 전 가장 먼저(순서):** ① **정렬 보조키 3언어 적용**(C1, 오라클 비결정성 차단) → ② **Python `_PRICE` `\s` 통일 + nameEn 길이 단위 통일**(C2) → ③ **트랩 겨냥 픽스처/유닛테스트**를 골든에 추가(스위트가 실제 트랩을 밟게) → ④ README 과장 수정(C4) + `py.typed`/`repository` 메타 채우기.

---

## ✅ 후속 조치 (2026-06-28, 같은 세션 적용)

**수정 완료 (검증됨):**
- **C1 정렬 비결정성** — 3언어+Dart `(yTop, x)` 보조키 적용, SPEC 갱신. (IMG_8393이 유일 동률, leftmost=694093이 기존 골든과 일치 → **골든 byte-identical**, 동작 불변·결정성만 확보.)
- **C2 Python `\s`** — `\d`→`[0-9]`+`re.ASCII` 제거(`\s` 유니코드 유지).
- **C4 README 과장** — "byte-for-byte"→"behaviourally identical(same structured output)", "degrade to unknown" 삭제 + **Known limitations 섹션** 신설.
- **C5 죽은 스키마** — Python `test_schema.py`로 46장 전체출력 스키마 검증(활성화). 3언어 출력 동일이라 1언어 검증=공유 형태 검증.
- **C6 "remove all spaces"** — SPEC을 "ASCII space(U+0020)"로 정정.
- **C7 ground-truth 확장** — 단위 문자열(개/100G) 추가. **할인기간은 의도적 제외**: OCR이 `2026.05121`로 뭉개 골든의 `2026-05-12`는 파서 추정(기획서 05-21 불일치의 정체) → ground-truth 부적격, parity-lock 유지.
- **트랩 테스트** — (A)yТоп 동률→leftmost, (B)NBSP 가격 파싱, 3언어 동일 기대값. 둘 다 구버전 코드에서 실패함을 논리 확인(teeth 있음).
- **🟡** nameEn 길이 단위 코드포인트 통일(Dart `runes.length`), discount 가드(`tagType==discount`일 때만), `py.typed` 추가, `requires-python>=3.10`, TS CI에 `npm run build`, 스키마 description·CONFORMANCE 정합, stale `parser_check` 참조 제거.

**의도적 보류 (Known limitations / open work로 문서화):**
- **C3 휴리스틱 순진성**(전화·kcal·g를 가격으로, 비-A포맷 미감지, 불가능 날짜) — 경계·문맥 가드는 골든 파급이 큰 설계 변경이라 별도 작업. README Known limitations에 정직히 명시.
- item regex 비앵커(긴 숫자열의 6자리 부분 포착) — 동상.
- unitPrice가 동값·동높이 토큰을 모두 skip(저순위 latent) — 보류.

**검증:** Dart 52 · Python 98(52+스키마46) · TS 52 전부 green, 골든 idempotent, 3언어 lint/type clean.
