#!/usr/bin/env node
// 西电知行 design tokens: one source, generated for every client.
//
//   node scripts/design_tokens.mjs          write the generated files
//   node scripts/design_tokens.mjs --check  fail if they are stale or a text
//                                           pair drops below 4.5:1
//
// Each theme supplies seven source colors per mode (paper, surface, ink,
// primary, primary pressed, coral, apricot); every other token is derived by
// the rules below, ported from the Claude Design handoff (zx-theme.js). Two
// ratios differ from the handoff: light --text-2 and --text-3 mix more ink so
// that --text-3 holds 4.5:1 on --bg, --surface and --bg-sunk in all themes.
//
// Outputs:
//   flutter_app/lib/design_system/zx_palette.g.dart
//   miniprogram/styles/zx-tokens.wxss

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// Values are the web's current themes (flutter_app/lib/core/theme/shared_colors.dart).
const THEMES = {
  zhushachi: {
    zh: '人本·初创', en: 'Humanist · Founding', descZh: '朱赤、暖白与杏黄', descEn: 'Vermilion, warm white and apricot',
    light: ['#F7F6F2', '#FFFEFA', '#181816', '#A43B32', '#7E2924', '#D9775F', '#E8B65D'],
    dark: ['#171714', '#20201C', '#F4F1E8', '#E08075', '#F09A8E', '#E89478', '#EBC474'],
  },
  zhuqing: {
    zh: '书院·青绿', en: 'Academy · Teal', descZh: '沉静青绿与纸白', descEn: 'Quiet teal and paper white',
    light: ['#F3F7F2', '#FFFEF9', '#202A23', '#426F52', '#2D5139', '#71967B', '#D4A955'],
    dark: ['#151A16', '#1D241F', '#F0F4EE', '#91C29C', '#B2D8B9', '#7FAB8A', '#D9B568'],
  },
  xingrenhuang: {
    zh: '杏黄·纸韵', en: 'Apricot · Paper', descZh: '古朴杏黄与墨褐', descEn: 'Antique apricot and ink brown',
    light: ['#FBF6EA', '#FFFEF8', '#30281E', '#94631F', '#694513', '#C38D3B', '#E3B660'],
    dark: ['#1B1812', '#252118', '#F6F0E3', '#E1B665', '#F0CE89', '#D39D4B', '#EAC774'],
  },
  mozhuxinye: {
    zh: '墨朱·新页', en: 'Ink Vermilion · New', descZh: '连续讨论流与墨朱金', descEn: 'Continuous threads in ink, vermilion and gold',
    light: ['#FFFFFF', '#FFFFFF', '#191917', '#AB3E36', '#852E29', '#D87569', '#E6B75D'],
    dark: ['#151513', '#1D1D1B', '#F5F5F0', '#E37D73', '#F0A096', '#F09A8E', '#E9C26E'],
  },
};
const DEFAULT_THEME = 'zhushachi';

const STATUS = {
  light: { success: '#44684F', warning: '#8A5A1E', danger: '#97382F', info: '#45687A' },
  dark: { success: '#8CC4A2', warning: '#E6BE74', danger: '#F29084', info: '#93BCCC' },
};

// Channel hues shared by every theme: same lightness and chroma, different hue.
const CHANNEL_HUES = [35, 160, 250, 80, 310, 125];

// ---------------------------------------------------------------- color math

const rgb = (h) => [0, 2, 4].map((i) => parseInt(h.replace('#', '').substr(i, 2), 16));
const hex = (a) => '#' + a.map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('').toUpperCase();
// t of a over (1 - t) of b.
const mix = (a, b, t) => { const x = rgb(a), y = rgb(b); return hex(x.map((v, i) => v * t + y[i] * (1 - t))); };
const withAlpha = (h, a) => ({ hex: h, alpha: a });

const luminance = (h) => rgb(h).map((v) => v / 255)
  .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
  .reduce((sum, v, i) => sum + v * [0.2126, 0.7152, 0.0722][i], 0);
const contrast = (a, b) => { const x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };

// OKLCH to sRGB hex; Flutter and WXSS cannot parse oklch().
function oklch(l, c, hDeg) {
  const h = (hDeg * Math.PI) / 180;
  const a = c * Math.cos(h), b = c * Math.sin(h);
  const l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = l - 0.0894841775 * a - 1.2914855480 * b;
  const [L, M, S] = [l_ ** 3, m_ ** 3, s_ ** 3];
  const lin = [
    4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
    -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
    -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S,
  ];
  return hex(lin.map((v) => 255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055)));
}

// ------------------------------------------------------------------ derivation

function derive(key, mode) {
  const dark = mode === 'dark';
  const [page, surf, ink, pri, act, coral, apr] = THEMES[key][mode];
  const st = STATUS[mode];
  const colors = {
    bg: page,
    bgSunk: dark ? mix('#000000', page, 0.3) : mix(ink, page, 0.045),
    surface: surf,
    raised: dark ? mix(ink, surf, 0.07) : surf,
    line: mix(ink, surf, dark ? 0.13 : 0.1),
    lineStrong: mix(ink, surf, dark ? 0.25 : 0.21),
    text: ink,
    text2: mix(ink, surf, dark ? 0.75 : 0.8),
    text3: mix(ink, surf, dark ? 0.58 : 0.7),
    primary: pri,
    primaryPressed: act,
    onPrimary: dark ? mix('#000000', pri, 0.8) : '#FFFFFF',
    primarySoft: mix(pri, surf, dark ? 0.2 : 0.1),
    seal: pri,
    sealSoft: mix(pri, surf, dark ? 0.14 : 0.07),
    accent: apr,
    accentSoft: mix(apr, surf, dark ? 0.18 : 0.24),
    accentInk: dark ? apr : mix('#000000', apr, 0.5),
    coral,
    onDanger: dark ? '#1A0F0D' : '#FFFFFF',
    onScrim: '#FFFFFF',
  };
  for (const k of ['success', 'warning', 'danger', 'info']) {
    colors[k] = st[k];
    colors[`${k}Soft`] = mix(st[k], surf, dark ? 0.17 : 0.12);
  }
  CHANNEL_HUES.forEach((h, i) => {
    colors[`channel${i + 1}`] = dark ? oklch(0.76, 0.1, h) : oklch(0.55, 0.11, h);
  });
  const translucent = {
    glass: withAlpha(surf, dark ? 0.74 : 0.8),
    primaryGlow: withAlpha(pri, dark ? 0.28 : 0.3),
    scrim: dark ? withAlpha('#000000', 0.62) : withAlpha('#1E1610', 0.42),
  };
  const heroStops = [mix(pri, surf, dark ? 0.24 : 0.13), mix(apr, surf, dark ? 0.14 : 0.2), surf];
  // [y offset, blur, color, alpha] per layer.
  const shadows = dark
    ? { shadow1: [[1, 2, '#000000', 0.5]], shadow2: [[18, 48, '#000000', 0.62], [2, 8, '#000000', 0.4]] }
    : { shadow1: [[1, 2, '#462D19', 0.06], [2, 10, '#462D19', 0.05]], shadow2: [[18, 48, '#462D19', 0.15], [3, 10, '#462D19', 0.06]] };
  return { colors, translucent, heroStops, shadows };
}

// Text that must stay readable: [foreground, background].
const CONTRAST_PAIRS = [
  ['text', 'bg'], ['text2', 'bg'], ['text3', 'bg'], ['text3', 'surface'], ['text3', 'bgSunk'], ['text3', 'raised'],
  ['primary', 'surface'], ['onPrimary', 'primary'], ['accentInk', 'accentSoft'], ['seal', 'sealSoft'],
  ['danger', 'surface'], ['onDanger', 'danger'],
  ['success', 'successSoft'], ['warning', 'warningSoft'], ['info', 'infoSoft'], ['danger', 'dangerSoft'],
];

function contrastFailures(all) {
  const failures = [];
  for (const [key, modes] of Object.entries(all)) {
    for (const [mode, { colors }] of Object.entries(modes)) {
      for (const [fg, bg] of CONTRAST_PAIRS) {
        const r = contrast(colors[fg], colors[bg]);
        if (r < 4.5) failures.push(`${key}/${mode}: ${fg} on ${bg} is ${r.toFixed(2)}:1`);
      }
    }
  }
  return failures;
}

// ------------------------------------------------------------------ emitters

const HEADER = 'GENERATED by scripts/design_tokens.mjs — do not edit. Run `node scripts/design_tokens.mjs`.';
const dartColor = (h, a = 1) => `Color(0x${Math.round(a * 255).toString(16).padStart(2, '0').toUpperCase()}${h.slice(1)})`;
const kebab = (s) => s.replace(/[A-Z0-9]+/g, (m) => '-' + m.toLowerCase()).replace(/^-/, '');

function emitDart(all) {
  const colorKeys = Object.keys(all[DEFAULT_THEME].light.colors);
  const translucentKeys = Object.keys(all[DEFAULT_THEME].light.translucent);
  const out = [];
  out.push(`// ${HEADER}`, '// ignore_for_file: prefer_const_constructors', '// dart format off', '', "import 'package:flutter/painting.dart';", '');
  out.push('/// Every value one theme needs in one brightness, already derived.');
  out.push('class ZxPalette {');
  out.push('  const ZxPalette({');
  for (const k of [...colorKeys, ...translucentKeys]) out.push(`    required this.${k},`);
  out.push('    required this.heroGradient,', '    required this.shadow1,', '    required this.shadow2,', '  });', '');
  for (const k of [...colorKeys, ...translucentKeys]) out.push(`  final Color ${k};`);
  out.push('', '  /// Header and empty-state wash: primary → apricot → surface at 125°.');
  out.push('  final List<Color> heroGradient;', '', '  /// Resting cards.', '  final List<BoxShadow> shadow1;', '', '  /// Menus, sheets and dialogs.', '  final List<BoxShadow> shadow2;', '');
  out.push('  List<Color> get channels => <Color>[channel1, channel2, channel3, channel4, channel5, channel6];');
  out.push('}', '');
  out.push('class ZxThemeInfo {');
  out.push('  const ZxThemeInfo({required this.key, required this.labelZh, required this.labelEn, required this.descriptionZh, required this.descriptionEn, required this.light, required this.dark});');
  out.push('  final String key;', '  final String labelZh;', '  final String labelEn;', '  final String descriptionZh;', '  final String descriptionEn;', '  final ZxPalette light;', '  final ZxPalette dark;', '}', '');
  out.push(`const String zxDefaultThemeKey = '${DEFAULT_THEME}';`, '');
  out.push('const List<ZxThemeInfo> zxThemes = <ZxThemeInfo>[');
  for (const [key, modes] of Object.entries(all)) {
    const t = THEMES[key];
    out.push('  ZxThemeInfo(', `    key: '${key}',`, `    labelZh: '${t.zh}',`, `    labelEn: '${t.en}',`, `    descriptionZh: '${t.descZh}',`, `    descriptionEn: '${t.descEn}',`);
    for (const mode of ['light', 'dark']) {
      const p = modes[mode];
      out.push(`    ${mode}: ZxPalette(`);
      for (const [k, v] of Object.entries(p.colors)) out.push(`      ${k}: ${dartColor(v)},`);
      for (const [k, v] of Object.entries(p.translucent)) out.push(`      ${k}: ${dartColor(v.hex, v.alpha)},`);
      out.push(`      heroGradient: <Color>[${p.heroStops.map((h) => dartColor(h)).join(', ')}],`);
      for (const s of ['shadow1', 'shadow2']) {
        out.push(`      ${s}: <BoxShadow>[${p.shadows[s].map(([y, blur, c, a]) => `BoxShadow(offset: Offset(0, ${y}), blurRadius: ${blur}, color: ${dartColor(c, a)})`).join(', ')}],`);
      }
      out.push('    ),');
    }
    out.push('  ),');
  }
  out.push('];', '');
  return out.join('\n');
}

function emitWxss(all) {
  const out = [`/* ${HEADER} */`, '/* Applied through the `theme-<key> color-mode-<light|dark>` classes set by utils/theme_i18n.js. */', ''];
  const block = (selector, p) => {
    out.push(`${selector} {`);
    for (const [k, v] of Object.entries(p.colors)) out.push(`  --zx-${kebab(k)}: ${v};`);
    for (const [k, v] of Object.entries(p.translucent)) {
      const [r, g, b] = rgb(v.hex);
      out.push(`  --zx-${kebab(k)}: rgba(${r}, ${g}, ${b}, ${v.alpha});`);
    }
    out.push(`  --zx-hero: linear-gradient(125deg, ${p.heroStops[0]} 0%, ${p.heroStops[1]} 52%, ${p.heroStops[2]} 100%);`);
    for (const s of ['shadow1', 'shadow2']) {
      const css = p.shadows[s].map(([y, blur, c, a]) => { const [r, g, b] = rgb(c); return `0 ${y * 2}rpx ${blur * 2}rpx rgba(${r}, ${g}, ${b}, ${a})`; }).join(', ');
      out.push(`  --zx-${kebab(s)}: ${css};`);
    }
    out.push('}', '');
  };
  block('page', all[DEFAULT_THEME].light);
  for (const [key, modes] of Object.entries(all)) {
    for (const mode of ['light', 'dark']) block(`.theme-${key}.color-mode-${mode}`, modes[mode]);
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------- main

const all = Object.fromEntries(Object.keys(THEMES).map((k) => [k, { light: derive(k, 'light'), dark: derive(k, 'dark') }]));
const failures = contrastFailures(all);
if (failures.length) {
  console.error('[design-tokens] contrast below 4.5:1:\n  ' + failures.join('\n  '));
  process.exit(1);
}

const outputs = {
  'flutter_app/lib/design_system/zx_palette.g.dart': emitDart(all),
  'miniprogram/styles/zx-tokens.wxss': emitWxss(all),
};

if (process.argv.includes('--check')) {
  const stale = Object.entries(outputs).filter(([p, c]) => {
    try { return readFileSync(join(ROOT, p), 'utf8') !== c; } catch { return true; }
  });
  if (stale.length) {
    console.error('[design-tokens] stale, run `node scripts/design_tokens.mjs`:\n  ' + stale.map(([p]) => p).join('\n  '));
    process.exit(1);
  }
  console.log('[design-tokens] up to date; all text pairs ≥ 4.5:1');
} else {
  for (const [p, c] of Object.entries(outputs)) writeFileSync(join(ROOT, p), c);
  console.log('[design-tokens] wrote\n  ' + Object.keys(outputs).join('\n  '));
}
