#!/usr/bin/env node
// KundliSaar "आपका अच्छा समय" flyer generator.
//
// For every placement code it writes, into docs/flyers/<code>/:
//   a5-print.pdf          A5 148x210 mm + 3 mm bleed (154x216 mm page), crop marks
//   a4-poster.pdf         A4 portrait poster for notice boards / shop walls
//   whatsapp-square.png   1080x1080
//   whatsapp-status.png   1080x1920
//   whatsapp-caption.txt  text to paste with the image (the image itself is not clickable)
//
// QR target: <base>/samay/?src=<code>. Every rendered output is decoded again
// (jsQR on a raster of the final page) and the run fails if any QR does not
// read back exactly that URL.
//
// Usage:
//   node make_flyers.mjs --src sample
//   node make_flyers.mjs --src a,b,c
//   node make_flyers.mjs --sources sources.csv
// Options: --base <url>  --phone <10 digits>  --out <dir>  --chrome <path>

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import QRCode from 'qrcode';
import jsQR from 'jsqr';
import { PNG } from 'pngjs';
import { chromium } from 'playwright-core';
import { PDFDocument } from 'pdf-lib';
import { execFileSync } from 'node:child_process';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..', '..');
const FONTS = path.join(REPO, 'assets', 'fonts');

// ---------------------------------------------------------------- arguments
function parseArgs(argv) {
  const a = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (!k.startsWith('--')) continue;
    const v = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : 'true';
    a[k.slice(2)] = v;
  }
  return a;
}
const args = parseArgs(process.argv.slice(2));
const BASE = (args.base || 'https://pallavsharmaofficial.github.io/KundliSaar').replace(/\/+$/, '');
const PHONE = String(args.phone || '9910144125').replace(/\D/g, '');
const OUT = path.resolve(args.out || path.join(REPO, 'docs', 'flyers'));
if (PHONE.length !== 10) die(`--phone must be a 10-digit Indian mobile number, got "${args.phone}"`);
const PHONE_PRETTY = `${PHONE.slice(0, 5)} ${PHONE.slice(5)}`;

function die(msg) { console.error(`make_flyers: ${msg}`); process.exit(1); }

function parseCsv(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/^﻿/, '');
  const rows = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const cells = [];
    let cur = '', q = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (q) {
        if (c === '"' && line[i + 1] === '"') { cur += '"'; i++; }
        else if (c === '"') q = false;
        else cur += c;
      } else if (c === '"') q = true;
      else if (c === ',') { cells.push(cur.trim()); cur = ''; }
      else cur += c;
    }
    cells.push(cur.trim());
    rows.push(cells);
  }
  if (rows.length && rows[0][0].toLowerCase() === 'code') rows.shift();
  return rows.map(([code, label = '']) => ({ code, label }));
}

let sources = [];
if (args.sources) sources = parseCsv(path.resolve(process.cwd(), args.sources));
if (args.src) sources.push(...args.src.split(',').map((s) => ({ code: s.trim(), label: '' })).filter((s) => s.code));
if (!sources.length) die('give --src a,b,c or --sources file.csv');
for (const s of sources) {
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(s.code) || s.code.length > 24)
    die(`placement code "${s.code}" must be lowercase letters/digits joined by hyphens, at most 24 characters (it is printed under the QR and lengthens the URL)`);
}

function findChrome() {
  const cands = [];
  if (args.chrome) cands.push(args.chrome);
  if (process.env.CHROME_PATH) cands.push(process.env.CHROME_PATH);
  const roots = [process.env.PLAYWRIGHT_BROWSERS_PATH, '/opt/pw-browsers'].filter(Boolean);
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    const dirs = fs.readdirSync(root).filter((d) => /^chromium-\d+$/.test(d)).sort().reverse();
    for (const d of dirs) cands.push(path.join(root, d, 'chrome-linux', 'chrome'));
  }
  cands.push('/opt/pw-browsers/chromium-1194/chrome-linux/chrome');
  const hit = cands.find((p) => fs.existsSync(p));
  if (!hit) die('no Chromium found; pass --chrome <path> or set PLAYWRIGHT_BROWSERS_PATH');
  return hit;
}

// ---------------------------------------------------------------- copy
const COPY = {
  brand: 'कुंडलीसार · KundliSaar',
  q1: 'क्या आप जानना चाहते हैं —',
  q2: 'आपका अच्छा समय',
  q3: 'कब आएगा?',
  sub: 'शास्त्रों के अनुसार, आपकी जन्म तिथि, समय और स्थान से — <b>मुफ़्त, बस 1 मिनट में</b>',
  steps: ['QR स्कैन करें', 'जन्म विवरण भरें', 'तुरंत जानें अपना अच्छा समय + <span class="nw">पूरी कुंडली PDF</span>'],
  trust1: 'ग्रहों की स्थिति NASA JPL के सार्वजनिक खगोलीय आँकड़ों पर आधारित गणना से',
  trust2: 'ज्योतिष शास्त्री चेतन शर्मा जी की प्रस्तुति',
  contact: `संपर्क: ${PHONE_PRETTY}`,
  fine: 'ज्योतिषीय जानकारी मार्गदर्शन के लिए है; कोई गारंटी नहीं।',
  tap: 'लिंक पर टैप करें',
};

// ---------------------------------------------------------------- drawn art
const C = {
  maroon: '#6b1d1d', sindoor: '#c1272d', haldi: '#e3a008', gold: '#b8860b',
  indigo: '#1f2a5e', parch: '#fdf6e8', parchDeep: '#f4e6c9', ink: '#221a14',
};

// A rising sun whose rays are the twelve hours of a dial, ringed by the
// 27 nakshatra beads: "time" and "the sky" in one mark. Drawn here, no stock art.
function sunClock() {
  const cx = 200, cy = 190;
  let rays = '', ticks = '', beads = '';
  for (let i = 0; i <= 12; i++) {
    const a = Math.PI - (i * Math.PI) / 12;
    const long = i % 3 === 0;
    const r1 = 74, r2 = long ? 128 : 112;
    const x1 = cx + r1 * Math.cos(a), y1 = cy - r1 * Math.sin(a);
    const x2 = cx + r2 * Math.cos(a), y2 = cy - r2 * Math.sin(a);
    if (i > 0 && i < 12) {
      // tapered ray as a thin triangle
      const w = long ? 6 : 3.6;
      const nx = -Math.sin(a) * w, ny = -Math.cos(a) * w;
      rays += `<path d="M${(x1 + nx).toFixed(2)} ${(y1 + ny).toFixed(2)} L${x2.toFixed(2)} ${y2.toFixed(2)} L${(x1 - nx).toFixed(2)} ${(y1 - ny).toFixed(2)} Z" fill="${long ? C.sindoor : C.haldi}"/>`;
    }
  }
  for (let i = 0; i <= 60; i++) {
    const a = Math.PI - (i * Math.PI) / 60;
    const r1 = 146, r2 = i % 5 === 0 ? 156 : 151;
    ticks += `<line x1="${(cx + r1 * Math.cos(a)).toFixed(2)}" y1="${(cy - r1 * Math.sin(a)).toFixed(2)}" x2="${(cx + r2 * Math.cos(a)).toFixed(2)}" y2="${(cy - r2 * Math.sin(a)).toFixed(2)}" stroke="${C.gold}" stroke-width="${i % 5 === 0 ? 2.2 : 1}" stroke-linecap="round"/>`;
  }
  for (let i = 0; i < 14; i++) {
    const a = Math.PI - ((i + 0.5) * Math.PI) / 14;
    const r = 172;
    beads += `<circle cx="${(cx + r * Math.cos(a)).toFixed(2)}" cy="${(cy - r * Math.sin(a)).toFixed(2)}" r="${i % 2 ? 2.6 : 4}" fill="${i % 2 ? C.gold : C.maroon}"/>`;
  }
  // scalloped horizon, echoing the arch line on site/index.html
  let scallop = 'M10 196';
  for (let x = 10; x < 390; x += 20) scallop += ` A10 10 0 0 1 ${x + 20} 196`;
  return `<svg class="sun" viewBox="0 0 400 206" aria-hidden="true">
  <defs>
    <radialGradient id="sunfill" cx="50%" cy="85%" r="75%">
      <stop offset="0" stop-color="#f6c64a"/><stop offset="0.65" stop-color="${C.haldi}"/><stop offset="1" stop-color="#d9811a"/>
    </radialGradient>
  </defs>
  <path d="M${cx - 146} ${cy} A146 146 0 0 1 ${cx + 146} ${cy}" fill="none" stroke="${C.gold}" stroke-width="1.2"/>
  ${ticks}${beads}${rays}
  <path d="M${cx - 64} ${cy} A64 64 0 0 1 ${cx + 64} ${cy} Z" fill="url(#sunfill)" stroke="${C.sindoor}" stroke-width="3"/>
  <path d="M${cx - 46} ${cy} A46 46 0 0 1 ${cx + 46} ${cy}" fill="none" stroke="${C.parch}" stroke-width="1.6" opacity="0.8"/>
  <line x1="${cx}" y1="${cy}" x2="${cx}" y2="${cy - 40}" stroke="${C.maroon}" stroke-width="4" stroke-linecap="round"/>
  <line x1="${cx}" y1="${cy}" x2="${cx + 26}" y2="${cy - 20}" stroke="${C.maroon}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="${cx}" cy="${cy}" r="5" fill="${C.maroon}"/>
  <line x1="0" y1="${cy}" x2="400" y2="${cy}" stroke="${C.maroon}" stroke-width="3"/>
  <path d="${scallop}" fill="none" stroke="${C.gold}" stroke-width="1.6"/>
</svg>`;
}

// Generic telephone-handset glyph (deliberately not any messaging app's logo).
const PHONE_GLYPH = `<svg class="glyph" viewBox="0 0 48 48" aria-hidden="true">
  <path d="M14.5 5.5c1.3-.6 2.8-.2 3.6 1l4.3 6.6c.7 1.1.6 2.6-.3 3.6l-2.8 3c2 4.4 5.4 7.9 9.8 9.9l3-2.8c1-.9 2.5-1 3.6-.3l6.6 4.3c1.2.8 1.6 2.3 1 3.6l-1.9 4c-.9 1.8-2.8 2.9-4.8 2.6C20.2 41.3 6.7 27.8 5 11.2c-.2-2 .8-3.9 2.6-4.8z" fill="currentColor"/>
</svg>`;

const TAP_GLYPH = `<svg class="tapg" viewBox="0 0 40 40" aria-hidden="true"><path d="M20 6v22M10 19l10 10 10-10" fill="none" stroke="currentColor" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

// ---------------------------------------------------------------- templates
function fontFaces() {
  const u = (f) => pathToFileURL(path.join(FONTS, f)).href;
  return `
@font-face { font-family: 'Yatra One'; src: url('${u('YatraOne-Regular.ttf')}'); }
@font-face { font-family: 'Mukta'; font-weight: 400; src: url('${u('Mukta-Regular.ttf')}'); }
@font-face { font-family: 'Mukta'; font-weight: 600; src: url('${u('Mukta-SemiBold.ttf')}'); }
@font-face { font-family: 'Mukta'; font-weight: 700; src: url('${u('Mukta-Bold.ttf')}'); }
@font-face { font-family: 'Tiro Devanagari Hindi'; src: url('${u('TiroDevanagariHindi-Regular.ttf')}'); }`;
}

function displayUrl(url) {
  // human-readable: no scheme, break opportunities after "/" and before "?"
  return url.replace(/^https?:\/\//, '').replace(/\//g, '/<wbr>').replace(/\?/g, '<wbr>?');
}

const COMMON_CSS = `
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: ${C.parch}; }
body { font-family: Mukta, sans-serif; color: ${C.ink}; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.page { position: relative; overflow: hidden;
  background: radial-gradient(ellipse at 50% 28%, #fffaf0 0%, ${C.parch} 45%, ${C.parchDeep} 100%); }
.frame { position: absolute; border: 1.2px solid ${C.gold}; pointer-events: none; }
.frame::after { content: ''; position: absolute; inset: 3px; border: 0.6px solid ${C.gold}; opacity: .7; }
.brand { font-family: 'Yatra One', serif; color: ${C.maroon}; text-align: center; letter-spacing: .02em; }
.brand .dot { color: ${C.gold}; }
.sun { display: block; margin: 0 auto; }
.q { font-family: 'Yatra One', serif; text-align: center; line-height: 1.12; }
.q .l1 { color: ${C.maroon}; display: block; }
.q .l2 { color: ${C.sindoor}; display: block; }
.q .l3 { color: ${C.maroon}; display: block; }
.sub { text-align: center; color: #3d2f24; font-family: 'Tiro Devanagari Hindi', Mukta, serif; }
.sub b { font-family: Mukta, sans-serif; font-weight: 700; color: ${C.maroon}; }
.qrcard { background: #fff; border: 1.4px solid ${C.maroon}; text-align: center; }
.qrcard svg { display: block; width: 100%; height: auto; }
.url { font-weight: 600; color: ${C.ink}; word-break: normal; overflow-wrap: anywhere; line-height: 1.2; }
.code { color: #5d5048; font-family: Mukta, sans-serif; letter-spacing: .04em; }
.steps { list-style: none; }
.steps li { display: flex; align-items: center; font-weight: 600; color: ${C.ink}; line-height: 1.22; }
.steps .n { flex: none; display: inline-flex; align-items: center; justify-content: center; border-radius: 50%;
  background: ${C.maroon}; color: ${C.parch}; font-weight: 700; font-family: Mukta, sans-serif; }
.steps .nw { white-space: nowrap; }
.steps li.last { color: ${C.maroon}; }
.steps li.last .n { background: ${C.sindoor}; }
.trust { text-align: center; color: #3d2f24; line-height: 1.35; }
.trust .who { color: ${C.indigo}; font-weight: 600; }
.band { position: absolute; left: 0; right: 0; bottom: 0; background: ${C.maroon}; color: ${C.parch}; text-align: center; line-height: 1.3; }
.band .contact { font-weight: 700; display: inline-flex; align-items: center; letter-spacing: .01em; }
.band .glyph { color: ${C.haldi}; }
.band .fine { color: #f1dfc0; }
.band .rule { height: 0; border-top: 1px solid rgba(227,160,8,.55); }
`;

function qrBlock(qrSvg, url, code, cls = '') {
  return `<div class="qrcard ${cls}">${qrSvg}<div class="url">${displayUrl(url)}</div><div class="code">${code}</div></div>`;
}
function stepsList(extra = '') {
  return `<ol class="steps ${extra}">${COPY.steps.map((s, i) => `<li class="${i === 2 ? 'last' : ''}"><span class="n">${i + 1}</span><span>${s}</span></li>`).join('')}</ol>`;
}
function questionHtml() {
  return `<h1 class="q"><span class="l1">${COPY.q1}</span><span class="l2">${COPY.q2}</span><span class="l3">${COPY.q3}</span></h1>`;
}
function bandHtml() {
  return `<div class="band"><div class="inner">
    <div class="contact">${PHONE_GLYPH}<span>${COPY.contact}</span></div>
    <div class="rule"></div>
    <div class="fine">${COPY.fine} &nbsp;·&nbsp; ${COPY.brand}</div>
  </div></div>`;
}
function trustHtml() {
  return `<div class="trust"><div>${COPY.trust1}</div><div class="who">${COPY.trust2}</div></div>`;
}

function doc(css, body) {
  return `<!DOCTYPE html><html lang="hi"><head><meta charset="utf-8"><style>${fontFaces()}${COMMON_CSS}${css}</style></head><body>${body}</body></html>`;
}

// A5: page 154x216 mm, trim inset 3 mm, safe area 5 mm inside trim (8 mm from page edge).
function a5(qrSvg, url, code) {
  const css = `
@page { size: 154mm 216mm; margin: 0; }
.page { width: 154mm; height: 216mm; }
.frame { left: 7mm; top: 7mm; right: 7mm; bottom: 34mm; border-bottom: none; }
.frame::after { bottom: -1px; border-bottom: none; }
.content { position: absolute; left: 10mm; right: 10mm; top: 10mm; }
.brand { font-size: 12pt; }
.sun { width: 88mm; margin-top: 1.5mm; }
.q { margin-top: 2.5mm; }
.q .l1 { font-size: 19pt; }
.q .l2 { font-size: 38pt; line-height: 1.05; margin-top: .6mm; }
.q .l3 { font-size: 30pt; line-height: 1.12; }
.sub { font-size: 11.2pt; line-height: 1.38; margin: 2.6mm auto 0; max-width: 118mm; }
.row { display: flex; align-items: center; gap: 6mm; margin: 5mm 1mm 0; }
.qrcard { width: 44mm; flex: none; padding: 1.2mm 1.2mm 1.6mm; border-radius: 2.2mm; }
.url { font-size: 6.4pt; padding: 0 .6mm; }
.code { font-size: 5pt; margin-top: .4mm; }
.steps li { font-size: 12pt; margin: 2.4mm 0; }
.steps .n { width: 7.2mm; height: 7.2mm; font-size: 12pt; margin-right: 2.6mm; }
.trust { position: absolute; left: 10mm; right: 10mm; bottom: 37.5mm; font-size: 8.6pt; }
.band { height: 34mm; }
.band .inner { position: absolute; left: 11mm; right: 11mm; top: 4.2mm; }
.band .contact { font-size: 17pt; }
.band .glyph { width: 7.5mm; height: 7.5mm; margin-right: 2.2mm; }
.band .rule { margin: 2mm 18mm 2mm; }
.band .fine { font-size: 8pt; }
.crop { position: absolute; inset: 0; width: 154mm; height: 216mm; }
`;
  // Crop marks live in the 3 mm bleed and stop 0.75 mm short of the trim corner;
  // each is a black hairline on a white underlay so it shows on any background.
  const m = [];
  for (const [x, dx] of [[3, -1], [151, 1]]) for (const [y, dy] of [[3, -1], [213, 1]]) {
    const hx2 = x + dx * 0.75, hx1 = dx < 0 ? 0 : 154;
    const vy2 = y + dy * 0.75, vy1 = dy < 0 ? 0 : 216;
    m.push(`M${hx1} ${y}H${hx2}`, `M${x} ${vy1}V${vy2}`);
  }
  const d = m.join('');
  const crop = `<svg class="crop" viewBox="0 0 154 216" aria-hidden="true">
    <path d="${d}" stroke="#fff" stroke-width="0.6" fill="none"/>
    <path d="${d}" stroke="#000" stroke-width="0.12" fill="none"/></svg>`;
  return doc(css, `<div class="page">
    <div class="frame"></div>
    <div class="content">
      <div class="brand">कुंडलीसार <span class="dot">·</span> KundliSaar</div>
      ${sunClock()}
      ${questionHtml()}
      <p class="sub">${COPY.sub}</p>
      <div class="row">${qrBlock(qrSvg, url, code)}${stepsList()}</div>
    </div>
    ${trustHtml()}
    ${bandHtml()}
    ${crop}
  </div>`);
}

// A4 poster, 210x297 mm, no bleed (most will come off an office/shop printer);
// everything stays >= 12 mm inside the edge so printer margins never clip it.
function a4(qrSvg, url, code) {
  const css = `
@page { size: 210mm 297mm; margin: 0; }
.page { width: 210mm; height: 297mm; }
.frame { left: 8mm; top: 8mm; right: 8mm; bottom: 46mm; border-bottom: none; }
.frame::after { bottom: -1px; border-bottom: none; }
.content { position: absolute; left: 13mm; right: 13mm; top: 13mm; }
.brand { font-size: 17pt; }
.sun { width: 112mm; margin-top: 1mm; }
.q { margin-top: 2mm; }
.q .l1 { font-size: 30pt; }
.q .l2 { font-size: 60pt; line-height: 1.04; margin-top: 1mm; }
.q .l3 { font-size: 48pt; line-height: 1.1; }
.sub { font-size: 16pt; line-height: 1.35; margin: 3.5mm auto 0; max-width: 165mm; }
.row { display: flex; align-items: center; gap: 9mm; margin: 7mm 3mm 0; }
.qrcard { width: 64mm; flex: none; padding: 1.8mm 1.8mm 2.2mm; border-radius: 3mm; }
.url { font-size: 9pt; padding: 0 1mm; }
.code { font-size: 6.5pt; margin-top: .6mm; }
.steps li { font-size: 18pt; margin: 3.6mm 0; }
.steps .n { width: 10.5mm; height: 10.5mm; font-size: 17pt; margin-right: 3.6mm; }
.trust { position: absolute; left: 14mm; right: 14mm; bottom: 51mm; font-size: 12pt; }
.band { height: 46mm; }
.band .inner { position: absolute; left: 14mm; right: 14mm; top: 6mm; }
.band .contact { font-size: 26pt; }
.band .glyph { width: 11mm; height: 11mm; margin-right: 3mm; }
.band .rule { margin: 3mm 30mm 3mm; }
.band .fine { font-size: 11pt; }
`;
  return doc(css, `<div class="page">
    <div class="frame"></div>
    <div class="content">
      <div class="brand">कुंडलीसार <span class="dot">·</span> KundliSaar</div>
      ${sunClock()}
      ${questionHtml()}
      <p class="sub">${COPY.sub}</p>
      <div class="row">${qrBlock(qrSvg, url, code)}${stepsList()}</div>
    </div>
    ${trustHtml()}
    ${bandHtml()}
  </div>`);
}

// WhatsApp images: viewed on the same phone, so the link text leads and the QR is secondary.
function linkPill(url) {
  return `<div class="tap">${TAP_GLYPH}<span>${COPY.tap}</span></div>
    <div class="pill">${displayUrl(url)}</div>`;
}
const WA_CSS = `
.tap { display: flex; align-items: center; justify-content: center; color: ${C.sindoor}; font-weight: 700; }
.pill { background: ${C.indigo}; color: #fff; font-weight: 700; text-align: center; overflow-wrap: anywhere; line-height: 1.18; }
`;

function square(qrSvg, url, code) {
  const css = WA_CSS + `
.page { width: 1080px; height: 1080px; }
.frame { left: 22px; top: 22px; right: 22px; bottom: 146px; border-bottom: none; border-width: 2px; }
.frame::after { inset: 6px; bottom: -2px; border-bottom: none; border-width: 1px; }
.content { position: absolute; left: 56px; right: 56px; top: 48px; }
.brand { font-size: 28px; }
.sun { width: 350px; margin-top: 6px; }
.q { margin-top: 4px; }
.q .l1 { font-size: 46px; }
.q .l2 { font-size: 94px; line-height: 1.04; }
.q .l3 { font-size: 70px; line-height: 1.1; }
.sub { font-size: 28px; line-height: 1.35; margin: 12px auto 0; max-width: 940px; }
.row { display: flex; align-items: center; gap: 34px; margin: 34px 10px 0; }
.qrcard { width: 200px; flex: none; padding: 6px; border-radius: 12px; }
.qrcard .url { display: none; }
.code { font-size: 14px; }
.linkbox { flex: 1; }
.tap { font-size: 36px; margin-bottom: 10px; }
.tapg { width: 36px; height: 36px; margin-right: 8px; }
.pill { font-size: 32px; padding: 16px 22px; border-radius: 18px; }
.steps.h { display: grid; grid-template-columns: 0.75fr 0.85fr 1.75fr; gap: 16px; margin: 34px 4px 0; }
.steps.h li { font-size: 25px; align-items: center; }
.steps.h .n { width: 40px; height: 40px; font-size: 23px; margin-right: 12px; }
.band { height: 146px; }
.band .inner { position: absolute; left: 50px; right: 50px; top: 16px; }
.band .contact { font-size: 44px; }
.band .glyph { width: 46px; height: 46px; margin-right: 14px; }
.band .rule { margin: 6px 240px 8px; }
.band .fine { font-size: 21px; }
.trust { display: none; }
`;
  return doc(css, `<div class="page">
    <div class="frame"></div>
    <div class="content">
      <div class="brand">कुंडलीसार <span class="dot">·</span> KundliSaar</div>
      ${sunClock()}
      ${questionHtml()}
      <p class="sub">${COPY.sub}</p>
      <div class="row">${qrBlock(qrSvg, url, code)}<div class="linkbox">${linkPill(url)}</div></div>
      ${stepsList('h')}
    </div>
    ${bandHtml()}
  </div>`);
}

function status(qrSvg, url, code) {
  const css = WA_CSS + `
.page { width: 1080px; height: 1920px; }
.frame { left: 28px; top: 28px; right: 28px; bottom: 210px; border-bottom: none; border-width: 2px; }
.frame::after { inset: 7px; bottom: -2px; border-bottom: none; border-width: 1px; }
.content { position: absolute; left: 64px; right: 64px; top: 96px; }
.brand { font-size: 38px; }
.sun { width: 520px; margin-top: 14px; }
.q { margin-top: 18px; }
.q .l1 { font-size: 62px; }
.q .l2 { font-size: 112px; line-height: 1.05; margin-top: 6px; }
.q .l3 { font-size: 92px; line-height: 1.12; }
.sub { font-size: 38px; line-height: 1.4; margin: 24px auto 0; max-width: 880px; }
.linkbox { margin: 48px 10px 0; }
.tap { font-size: 50px; margin-bottom: 18px; }
.tapg { width: 50px; height: 50px; margin-right: 12px; }
.pill { font-size: 46px; padding: 26px 34px; border-radius: 28px; }
.lower { display: flex; align-items: center; gap: 44px; margin: 44px 20px 0; }
.qrcard { width: 250px; flex: none; padding: 8px; border-radius: 14px; }
.qrcard .url { display: none; }
.code { font-size: 16px; }
.steps li { font-size: 36px; margin: 14px 0; }
.steps .n { width: 62px; height: 62px; font-size: 36px; margin-right: 22px; }
.trust { position: absolute; left: 70px; right: 70px; bottom: 236px; font-size: 27px; }
.band { height: 210px; }
.band .inner { position: absolute; left: 60px; right: 60px; top: 30px; }
.band .contact { font-size: 62px; }
.band .glyph { width: 64px; height: 64px; margin-right: 18px; }
.band .rule { margin: 14px 220px 14px; }
.band .fine { font-size: 27px; }
`;
  return doc(css, `<div class="page">
    <div class="frame"></div>
    <div class="content">
      <div class="brand">कुंडलीसार <span class="dot">·</span> KundliSaar</div>
      ${sunClock()}
      ${questionHtml()}
      <p class="sub">${COPY.sub}</p>
      <div class="linkbox">${linkPill(url)}</div>
      <div class="lower">${qrBlock(qrSvg, url, code)}${stepsList()}</div>
    </div>
    ${trustHtml()}
    ${bandHtml()}
  </div>`);
}

function caption(url) {
  return [
    `क्या आप जानना चाहते हैं — आपका अच्छा समय कब आएगा?`,
    ``,
    `शास्त्रों के अनुसार, आपकी जन्म तिथि, समय और स्थान से — मुफ़्त, बस 1 मिनट में।`,
    `इस लिंक पर टैप करें: ${url}`,
    ``,
    `${COPY.trust2}। ${COPY.contact}`,
    `${COPY.fine}`,
    ``,
  ].join('\n');
}

// ---------------------------------------------------------------- render + verify
const PT = 72 / 25.4;
// Chrome rounds the page to whole CSS pixels. Snap the MediaBox to the exact size
// (top-aligned; any difference is a fraction of a point inside the bleed) and,
// for print files, declare TrimBox/BleedBox so prepress software finds the trim.
async function fixPdfBoxes(file, wMm, hMm, bleedMm) {
  const pdf = await PDFDocument.load(fs.readFileSync(file));
  const pg = pdf.getPage(0);
  const { height: hChrome } = pg.getMediaBox();
  const W = wMm * PT, H = hMm * PT, y0 = hChrome - H;
  pg.setMediaBox(0, y0, W, H);
  pg.setCropBox(0, y0, W, H);
  pg.setBleedBox(0, y0, W, H);
  const b = bleedMm * PT;
  pg.setTrimBox(b, y0 + b, W - 2 * b, H - 2 * b);
  pdf.setTitle('KundliSaar — आपका अच्छा समय');
  pdf.setProducer('tools/flyer/make_flyers.mjs');
  fs.writeFileSync(file, await pdf.save());
}

// If poppler's pdftoppm is installed, rasterise the finished PDF and decode its QR
// too, so the check covers the file that goes to the printer, not just the screen render.
function pdfQr(file) {
  try {
    // PPM (P6) on stdout: trivial to parse, no PNG decoder quirks.
    const buf = execFileSync('pdftoppm', ['-r', '150', '-singlefile', file], { maxBuffer: 256 << 20 });
    const head = buf.subarray(0, 64).toString('latin1').match(/^P6\s+(\d+)\s+(\d+)\s+(\d+)\s/);
    if (!head) throw new Error('unexpected pdftoppm output');
    const [, w, h] = head.map(Number), off = head[0].length;
    const rgba = new Uint8ClampedArray(w * h * 4);
    for (let i = 0, j = off; i < w * h; i++, j += 3) {
      rgba[i * 4] = buf[j]; rgba[i * 4 + 1] = buf[j + 1]; rgba[i * 4 + 2] = buf[j + 2]; rgba[i * 4 + 3] = 255;
    }
    const r = jsQR(rgba, w, h, { inversionAttempts: 'dontInvert' });
    return { checked: true, data: r ? r.data : null };
  } catch (e) {
    if (e.code === 'ENOENT') return { checked: false };
    throw e;
  }
}

function decodePng(buf) {
  const png = PNG.sync.read(buf);
  const r = jsQR(new Uint8ClampedArray(png.data.buffer, png.data.byteOffset, png.data.length), png.width, png.height, { inversionAttempts: 'dontInvert' });
  return r ? r.data : null;
}

async function checkFontsAndOverflow(page, label, safePx) {
  const problems = await page.evaluate(async (safe) => {
    await document.fonts.ready;
    const out = [];
    for (const f of ['Yatra One', 'Mukta', 'Tiro Devanagari Hindi'])
      if (!document.fonts.check(`16px "${f}"`, 'क')) out.push(`font not loaded: ${f}`);
    const page = document.querySelector('.page').getBoundingClientRect();
    for (const el of document.querySelectorAll('.content, .trust, .band .inner, .q span, .steps li, .pill, .qrcard')) {
      const r = el.getBoundingClientRect();
      if (r.width === 0) continue;
      if (r.right > page.right + 0.5 || r.bottom > page.bottom + 0.5 || r.left < page.left - 0.5)
        out.push(`overflows page: ${el.className || el.tagName}`);
      if (el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflow !== 'visible')
        out.push(`clipped: ${el.className}`);
    }
    // safe area: every piece of text sits at least `safe` px inside the page edge
    // (A5: 3 mm bleed + 5 mm inside trim)
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let n; (n = walker.nextNode());) {
      if (!n.textContent.trim()) continue;
      const rg = document.createRange(); rg.selectNodeContents(n);
      for (const r of rg.getClientRects()) {
        if (r.width === 0) continue;
        if (r.left < page.left + safe - 0.5 || r.right > page.right - safe + 0.5 || r.top < page.top + safe - 0.5 || r.bottom > page.bottom - safe + 0.5)
          out.push(`text outside safe area: "${n.textContent.trim().slice(0, 30)}"`);
      }
    }
    // the content column must end above the trust line, the trust line above the band
    const c = document.querySelector('.content').getBoundingClientRect();
    const t = document.querySelector('.trust');
    const b = document.querySelector('.band').getBoundingClientRect();
    const tr = t && getComputedStyle(t).display !== 'none' ? t.getBoundingClientRect() : null;
    if (tr && c.bottom > tr.top - 2) out.push(`content (${c.bottom.toFixed(0)}) runs into trust line (${tr.top.toFixed(0)})`);
    if (!tr && c.bottom > b.top - 2) out.push(`content runs into contact band`);
    if (tr && tr.bottom > b.top) out.push('trust line runs into contact band');
    return [...new Set(out)];
  }, safePx);
  if (problems.length) {
    const msg = `${label}: ${problems.join('; ')}`;
    if (args.preview) console.warn(`WARN ${msg}`); else throw new Error(msg);
  }
}

async function main() {
  const chrome = findChrome();
  console.log(`Chromium: ${chrome}`);
  const browser = await chromium.launch({ executablePath: chrome });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ks-flyer-'));
  const report = [];
  try {
    for (const { code, label } of sources) {
      const url = `${BASE}/samay/?src=${encodeURIComponent(code)}`;
      const qrSvg = await QRCode.toString(url, { type: 'svg', errorCorrectionLevel: 'Q', margin: 4, color: { dark: '#000000', light: '#ffffff' } });
      const dir = path.join(OUT, code);
      fs.mkdirSync(dir, { recursive: true });

      const jobs = [
        { name: 'a5-print.pdf', html: a5(qrSvg, url, code), w: 154, h: 216, unit: 'mm', bleed: 3, safe: (8 / 25.4) * 96 },
        { name: 'a4-poster.pdf', html: a4(qrSvg, url, code), w: 210, h: 297, unit: 'mm', safe: (10 / 25.4) * 96 },
        { name: 'whatsapp-square.png', html: square(qrSvg, url, code), w: 1080, h: 1080, unit: 'px', safe: 24 },
        { name: 'whatsapp-status.png', html: status(qrSvg, url, code), w: 1080, h: 1920, unit: 'px', safe: 24 },
      ];
      for (const j of jobs) {
        const htmlFile = path.join(tmp, `${code}-${j.name}.html`);
        fs.writeFileSync(htmlFile, j.html);
        const pxW = j.unit === 'mm' ? Math.round((j.w / 25.4) * 96) : j.w;
        const pxH = j.unit === 'mm' ? Math.round((j.h / 25.4) * 96) : j.h;
        // Raster check at roughly 150 dpi for print sizes (a poor phone camera), 1:1 for PNGs.
        const scale = j.unit === 'mm' ? 1.6 : 1;
        const ctx = await browser.newContext({ viewport: { width: pxW, height: pxH }, deviceScaleFactor: scale });
        const page = await ctx.newPage();
        await page.goto(pathToFileURL(htmlFile).href, { waitUntil: 'load' });
        await page.evaluate(() => document.fonts.ready);
        await checkFontsAndOverflow(page, `${code}/${j.name}`, j.safe);
        const shot = await page.screenshot({ type: 'png', clip: { x: 0, y: 0, width: pxW, height: pxH } });
        const out = path.join(dir, j.name);
        if (j.unit === 'mm') {
          await page.pdf({ path: out, width: `${j.w}mm`, height: `${j.h}mm`, printBackground: true, preferCSSPageSize: true, margin: { top: 0, right: 0, bottom: 0, left: 0 } });
          await fixPdfBoxes(out, j.w, j.h, j.bleed || 0);
          if (args.preview) fs.writeFileSync(path.join(tmp, `${code}-${j.name}.png`), shot);
        } else {
          fs.writeFileSync(out, shot);
        }
        await ctx.close();
        const got = decodePng(shot);
        const ok = got === url;
        report.push({ file: path.relative(REPO, out), ok, got });
        if (!ok) throw new Error(`QR check failed for ${out}: decoded ${JSON.stringify(got)}, expected ${url}`);
        if (j.unit === 'mm') {
          const r = pdfQr(out);
          if (r.checked) {
            report.push({ file: path.relative(REPO, out) + ' (pdftoppm 150 dpi)', ok: r.data === url, got: r.data });
            if (r.data !== url) throw new Error(`QR check failed on rasterised PDF ${out}: decoded ${JSON.stringify(r.data)}`);
          }
        }
      }
      fs.writeFileSync(path.join(dir, 'whatsapp-caption.txt'), caption(url));
      console.log(`  ${code}${label ? `  (${label})` : ''}  ->  ${path.relative(REPO, dir)}/   QR ok: ${url}`);
    }
  } finally {
    await browser.close();
    if (args.preview) console.log(`previews of the PDFs: ${tmp}`);
    else fs.rmSync(tmp, { recursive: true, force: true });
  }
  console.log(`QR decode check: ${report.filter((r) => r.ok).length}/${report.length} outputs read back the exact URL.`);
}

main().catch((e) => { console.error(e.stack || e.message); process.exit(1); });
