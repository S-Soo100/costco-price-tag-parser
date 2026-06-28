/**
 * Costco A-format price-tag parser. TypeScript port of the canonical Dart parser.
 * See ../../../spec/SPEC.md for the language-neutral algorithm this implements.
 */

import type { DiscountInfo, OcrLine, PriceTagData, TagType, UnitPrice } from "./types.js";

const PURE_ITEM = /^(\d{6})(\+?)$/;
const ITEM = /(\d{6})(\+?)/;
const PRICE = /(\d[\d,]{2,})\s*원/;
const COMMA_NUM = /\d{1,3}(?:,\d{3})+/;
const DATE = /(\d{4})[.\/](\d{1,2})[.\/]?(\d{1,2})/g;
const UNIT = /단가\s*\/\s*([^\s]+)/;
const LATIN = /[A-Za-z]/;

interface PT {
  v: number;
  h: number;
  y: number;
}

const pad = (s: string | undefined): string => (s ?? "").padStart(2, "0");
const despace = (s: string): string => s.replace(/ /g, "");

export function parsePriceTag(lines: OcrLine[]): PriceTagData {
  const raw = lines.map((l) => l.text).join("\n");
  const blob = lines.map((l) => l.text).join(" ");

  // --- itemNumber: prefer a line that is ONLY a 6-digit number (topmost) ---
  let item: string | null = null;
  let plus = false;
  // Stable reading order: top-to-bottom, then left-to-right. The `x` tiebreak
  // makes selection deterministic when two lines share yTop. See spec/SPEC.md.
  const byTop = (a: OcrLine, b: OcrLine): number => a.yTop - b.yTop || a.x - b.x;
  let pick: OcrLine | undefined = lines
    .filter((l) => PURE_ITEM.test(despace(l.text)))
    .sort(byTop)[0];
  if (!pick) {
    pick = lines.filter((l) => ITEM.test(despace(l.text))).sort(byTop)[0];
  }
  if (pick) {
    const m = ITEM.exec(despace(pick.text));
    if (m) {
      item = m[1];
      plus = m[2] === "+";
    }
  }

  // --- price tokens (value, glyph-height, vertical pos), in input order ---
  const pts: PT[] = [];
  for (const l of lines) {
    let v: number | null = null;
    const m = PRICE.exec(l.text);
    if (m) {
      v = parseInt(m[1].replace(/,/g, ""), 10);
    } else {
      const cm = COMMA_NUM.exec(l.text); // price whose '원' got split off
      if (cm) v = parseInt(cm[0].replace(/,/g, ""), 10);
    }
    if (v !== null) pts.push({ v, h: l.h, y: l.yTop });
  }

  let finalTok: PT | null = null;
  for (const p of pts) {
    if (finalTok === null || p.h > finalTok.h) finalTok = p;
  }
  const finalPrice = finalTok ? finalTok.v : null;

  // --- tag type + discount ---
  const isDisc = blob.includes("할인행사");
  let tag: TagType;
  if (item === null && finalPrice === null) {
    tag = "unknown";
  } else {
    tag = isDisc ? "discount" : "regular";
  }

  let disc: DiscountInfo | null = null;
  if (tag === "discount") {
    let orig: number | null = null;
    if (finalPrice !== null) {
      for (const p of pts) {
        if (p.v > finalPrice && (orig === null || p.v > orig)) orig = p.v;
      }
    }
    const amt = orig !== null && finalPrice !== null ? orig - finalPrice : null;
    const dates = [...blob.matchAll(DATE)];
    let ps: string | null = null;
    let pe: string | null = null;
    if (dates.length > 0) ps = `${dates[0][1]}-${pad(dates[0][2])}-${pad(dates[0][3])}`;
    if (dates.length > 1) pe = `${dates[1][1]}-${pad(dates[1][2])}-${pad(dates[1][3])}`;
    disc = { originalPrice: orig, discountAmount: amt, periodStart: ps, periodEnd: pe };
  }

  // --- unit price: "단가 / <unit>" label + nearest small price ---
  let up: UnitPrice | null = null;
  let labelY: number | null = null;
  let unit: string | null = null;
  for (const l of lines) {
    const um = UNIT.exec(l.text);
    if (um) {
      labelY = l.yTop;
      unit = um[1];
      break;
    }
  }
  if (labelY !== null && unit !== null) {
    let best: PT | null = null;
    for (const p of pts) {
      if (finalTok !== null && p.v === finalTok.v && p.h === finalTok.h) continue; // skip final
      if (best === null || Math.abs(p.y - labelY) < Math.abs(best.y - labelY)) best = p;
    }
    if (best !== null) up = { value: best.v, unit };
  }

  // --- English name (best-effort): mostly-ASCII line with a space ---
  // Iterate CODE POINTS via spread, not .length (UTF-16 units).
  let nameEn: string | null = null;
  for (const l of lines) {
    const t = l.text.trim();
    const cps = [...t];
    if (cps.length < 5 || !t.includes(" ")) continue;
    const asciiPrintable = cps.filter((c) => {
      const o = c.codePointAt(0) ?? 0;
      return o > 32 && o < 128;
    }).length;
    if (asciiPrintable / cps.length > 0.7 && LATIN.test(t)) {
      nameEn = t;
      break;
    }
  }

  return {
    schemaVersion: "0.1",
    itemNumber: item,
    plusMark: plus,
    nameKo: null,
    model: null,
    nameEn,
    finalPrice,
    tagType: tag,
    discount: disc,
    unitPrice: up,
    rawText: raw,
  };
}
