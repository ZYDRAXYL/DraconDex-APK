// Procress 19 part 8: main.dart.js must not grow past its baseline by more
// than 10 % without anyone noticing. It is the one file every visit to the
// web build downloads before anything draws (7.3 MB at the baseline), and a
// new package pulled into lib/ shows up here first — a heavy dependency
// imported for one screen can add a megabyte without a single test changing.
//
//   node tools/web-size.mjs            check flutter/build/web against the baseline
//   node tools/web-size.mjs --update   write the current size as the baseline
//
// Growing on purpose is fine: run --update in the same pull request, so the
// new number is reviewed next to the change that caused it.
import { readFileSync, writeFileSync, statSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const BASELINE = join(ROOT, 'flutter/web-size-baseline.json');
const ALLOWED = 1.10;
const files = ['main.dart.js'];

const sizes = Object.fromEntries(files.map((f) => {
  const p = join(ROOT, 'flutter/build/web', f);
  if (!existsSync(p)) { console.error(`::error::${p} is missing — run flutter build web --release first`); process.exit(1); }
  return [f, statSync(p).size];
}));

if (process.argv.includes('--update')) {
  writeFileSync(BASELINE, JSON.stringify(sizes, null, 2) + '\n');
  console.log(`baseline written: ${JSON.stringify(sizes)}`);
  process.exit(0);
}

const base = JSON.parse(readFileSync(BASELINE, 'utf8'));
let bad = 0;
for (const f of files) {
  const now = sizes[f], was = base[f];
  const pct = ((now / was - 1) * 100).toFixed(1);
  const line = `${f}: ${(now / 1048576).toFixed(2)} MB (baseline ${(was / 1048576).toFixed(2)} MB, ${pct >= 0 ? '+' : ''}${pct} %)`;
  if (now > was * ALLOWED) {
    console.error(`::error::${line} — over the ${Math.round((ALLOWED - 1) * 100)} % allowance. If the growth is wanted, run node tools/web-size.mjs --update in this PR.`);
    bad++;
  } else console.log(line);
}
process.exit(bad ? 1 : 0);
