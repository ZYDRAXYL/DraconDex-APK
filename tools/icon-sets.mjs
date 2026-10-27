#!/usr/bin/env node
// Procress 29 part 7 — the open-source icon sets the desktop's icon picker
// offers (Lucide, Phosphor, Tabler), as Flutter assets, so an icon chosen on
// the desktop (stored as svg:<set>/<name>) draws here too (lib/core/icon_sets.dart).
// The same three packages the desktop vendors with its own tools/icon-sets.mjs
// (DraconDex-EXE), written as JSON instead of a script. Offline; one file per
// set, read the first time a set's icon is drawn.
//
//   npm pack lucide-static @phosphor-icons/core @tabler/icons   (anywhere)
//   tar -xzf each into its own folder, then:
//   node tools/icon-sets.mjs --lucide <dir>/package --phosphor <dir>/package --tabler <dir>/package
import { readFileSync, readdirSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'flutter', 'assets', 'icon-sets');
const arg = (k) => { const i = process.argv.indexOf(`--${k}`); return i > 0 ? process.argv[i + 1] : null; };

function inner(svg) {
  return svg.replace(/<!--[\s\S]*?-->/g, '').replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')
    .replace(/<path stroke="none" d="M0 0h24v24H0z" fill="none"\s*\/>/g, '')
    .replace(/\s*\n\s*/g, '').replace(/\s+\/>/g, '/>').trim();
}
const words = (list) => [...new Set((list || []).flatMap((w) => String(w).toLowerCase().split(/[\s-]+/)))].slice(0, 8).join(' ');
const pkgVersion = (dir) => JSON.parse(readFileSync(path.join(dir, 'package.json'), 'utf8')).version;

function write(set, meta, icons) {
  mkdirSync(out, { recursive: true });
  const sorted = Object.fromEntries(Object.entries(icons).sort(([a], [b]) => a.localeCompare(b)).map(([n, v]) => [n, [v.svg, v.tags]]));
  writeFileSync(path.join(out, `${set}.json`), JSON.stringify({ generated: `tools/icon-sets.mjs — ${meta.label} ${meta.version}, ${meta.license}`, label: meta.label, viewBox: meta.viewBox, attrs: meta.attrs, icons: sorted }));
  console.log(`${set}: ${Object.keys(icons).length} icons`);
}
function fromDir(dir, sub, tagsOf) {
  const icons = {};
  for (const f of readdirSync(path.join(dir, sub)).filter((n) => n.endsWith('.svg'))) {
    const name = f.slice(0, -4);
    icons[name] = { svg: inner(readFileSync(path.join(dir, sub, f), 'utf8')), tags: words(tagsOf(name)) };
  }
  return icons;
}
const STROKE = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';

const lucide = arg('lucide');
if (lucide) {
  const tags = JSON.parse(readFileSync(path.join(lucide, 'tags.json'), 'utf8'));
  write('lucide', { label: 'Lucide', version: pkgVersion(lucide), license: 'ISC', viewBox: '0 0 24 24', attrs: STROKE }, fromDir(lucide, 'icons', (n) => tags[n]));
  copyFileSync(path.join(lucide, 'LICENSE'), path.join(out, 'LICENSE-lucide'));
}
const phosphor = arg('phosphor');
if (phosphor) {
  const { icons: list } = await import(path.join(phosphor, 'dist', 'index.mjs'));
  const tags = Object.fromEntries(list.map((i) => [i.name, i.tags]));
  write('phosphor', { label: 'Phosphor', version: pkgVersion(phosphor), license: 'MIT', viewBox: '0 0 256 256', attrs: 'fill="currentColor"' }, fromDir(phosphor, 'assets/regular', (n) => tags[n]));
  copyFileSync(path.join(phosphor, 'LICENSE'), path.join(out, 'LICENSE-phosphor'));
}
const tabler = arg('tabler');
if (tabler) {
  const meta = JSON.parse(readFileSync(path.join(tabler, 'icons.json'), 'utf8'));
  write('tabler', { label: 'Tabler', version: pkgVersion(tabler), license: 'MIT', viewBox: '0 0 24 24', attrs: STROKE }, fromDir(tabler, 'icons/outline', (n) => meta[n]?.tags));
  copyFileSync(path.join(tabler, 'LICENSE'), path.join(out, 'LICENSE-tabler'));
}
