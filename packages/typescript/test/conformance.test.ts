/**
 * Conformance suite — same fixtures + golden as the Dart/Python ports.
 * See ../../../spec/CONFORMANCE.md.
 */

import { describe, expect, it } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parsePriceTag, type OcrLine } from "../src/index.js";

function repoRoot(): string {
  let dir = dirname(fileURLToPath(import.meta.url));
  while (!existsSync(join(dir, "spec", "fixtures"))) {
    const parent = dirname(dir);
    if (parent === dir) throw new Error("repo root (with spec/fixtures) not found");
    dir = parent;
  }
  return dir;
}

const ROOT = repoRoot();
const FIXTURES: Record<string, OcrLine[]> = JSON.parse(
  readFileSync(join(ROOT, "spec/fixtures/ocr_raw.json"), "utf8"),
);
const GOLDEN: Record<string, Record<string, unknown>> = JSON.parse(
  readFileSync(join(ROOT, "spec/golden/expected.json"), "utf8"),
);

const parse = (fn: string) => parsePriceTag(FIXTURES[fn]);

describe("ground truth (human-verified photos)", () => {
  it("IMG_3374 — discount tag", () => {
    const t = parse("IMG_3374.JPG");
    expect(t.itemNumber).toBe("685246");
    expect(t.plusMark).toBe(true);
    expect(t.finalPrice).toBe(349900);
    expect(t.tagType).toBe("discount");
    expect(t.discount?.originalPrice).toBe(389900);
    expect(t.discount?.discountAmount).toBe(40000);
  });

  it("IMG_3379 — regular tag with unit price", () => {
    const t = parse("IMG_3379.JPG");
    expect(t.itemNumber).toBe("649221");
    expect(t.finalPrice).toBe(23890);
    expect(t.tagType).toBe("regular");
    expect(t.unitPrice?.value).toBe(11945);
    expect(t.unitPrice?.unit).toBe("개");
  });

  it("IMG_3383 — regular tag with unit price", () => {
    const t = parse("IMG_3383.JPG");
    expect(t.itemNumber).toBe("654718");
    expect(t.finalPrice).toBe(119900);
    expect(t.unitPrice?.value).toBe(11990);
    expect(t.unitPrice?.unit).toBe("100G");
  });
});

describe("golden parity (all fixtures)", () => {
  it("golden covers every fixture", () => {
    expect(new Set(Object.keys(GOLDEN))).toEqual(new Set(Object.keys(FIXTURES)));
  });

  for (const fn of Object.keys(FIXTURES).sort()) {
    it(fn, () => {
      const { rawText: _rawText, ...got } = parse(fn);
      expect(got).toEqual(GOLDEN[fn]);
    });
  }
});

// Synthetic inputs that the real fixtures don't exercise — they pin the
// cross-language hazards the review surfaced (see spec/SPEC.md "parity notes").
describe("parity traps (synthetic inputs)", () => {
  it("yTop tie resolves to the left-most item (deterministic)", () => {
    // Right-most listed first; without the x tiebreak a naive sort keeps it.
    const tag = parsePriceTag([
      { text: "222222", x: 0.5, yTop: 0.3, w: 0.1, h: 0.05, conf: 1 },
      { text: "111111", x: 0.1, yTop: 0.3, w: 0.1, h: 0.05, conf: 1 },
    ]);
    expect(tag.itemNumber).toBe("111111");
  });

  it("non-ASCII space (NBSP) before 원 still yields the price", () => {
    const tag = parsePriceTag([
      { text: "685246", x: 0.3, yTop: 0.1, w: 0.1, h: 0.03, conf: 1 },
      { text: "12345 원", x: 0.3, yTop: 0.5, w: 0.2, h: 0.1, conf: 1 },
    ]);
    expect(tag.finalPrice).toBe(12345);
    expect(tag.itemNumber).toBe("685246");
  });

  it("a nutrition/weight figure is not taken as the price", () => {
    // "1,584g" is taller (bigger h) — without the weight guard it would win.
    const tag = parsePriceTag([
      { text: "685246", x: 0.3, yTop: 0.1, w: 0.1, h: 0.03, conf: 1 },
      { text: "1,584g", x: 0.3, yTop: 0.4, w: 0.2, h: 0.2, conf: 1 },
      { text: "9,900원", x: 0.3, yTop: 0.6, w: 0.2, h: 0.1, conf: 1 },
    ]);
    expect(tag.finalPrice).toBe(9900);
    expect(tag.itemNumber).toBe("685246");
  });

  it("a 6-digit run inside a longer number is not an item number", () => {
    expect(
      parsePriceTag([{ text: "ITEM: 3663092", x: 0.1, yTop: 0.3, w: 0.3, h: 0.05, conf: 1 }])
        .itemNumber,
    ).toBeNull();
    // …but a properly bounded 6-digit run still is.
    expect(
      parsePriceTag([{ text: "#512905", x: 0.1, yTop: 0.3, w: 0.2, h: 0.05, conf: 1 }]).itemNumber,
    ).toBe("512905");
  });

  it("a calendar-implausible date is dropped", () => {
    const tag = parsePriceTag([
      { text: "685246", x: 0.3, yTop: 0.1, w: 0.1, h: 0.03, conf: 1 },
      { text: "할인행사", x: 0.3, yTop: 0.2, w: 0.2, h: 0.03, conf: 1 },
      { text: "10,000원", x: 0.3, yTop: 0.5, w: 0.2, h: 0.2, conf: 1 },
      { text: "20,000원", x: 0.3, yTop: 0.3, w: 0.2, h: 0.05, conf: 1 },
      { text: "2026.13.45", x: 0.3, yTop: 0.7, w: 0.2, h: 0.03, conf: 1 },
    ]);
    expect(tag.tagType).toBe("discount");
    expect(tag.discount?.originalPrice).toBe(20000);
    expect(tag.discount?.periodStart).toBeNull();
    expect(tag.discount?.periodEnd).toBeNull();
  });
});
