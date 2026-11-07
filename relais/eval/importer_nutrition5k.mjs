// Prépare un jeu d'essai à partir de Nutrition5k (Google, CC BY 4.0) :
// https://github.com/google-research-datasets/Nutrition5k
//
//   node eval/importer_nutrition5k.mjs ./n5k [nombre=150] [graine=1]
//
// Télécharge `nombre` plats pris au hasard (graine fixe : même tirage à chaque
// fois), convertit la photo de dessus en JPEG 1024 px (ffmpeg requis) et écrit
// x.jpg + x.json {"kcal", "grammes", "source"} au format de comparer.js.
// Les plats aberrants (poids ou calories hors d'une assiette réaliste) sont écartés.
// Crédit à citer si les résultats sont publiés : Thames et al., CVPR 2021.
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const BASE = 'https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset';
const [dossier, n = '150', graine = '1'] = process.argv.slice(2);
export function lirePlats(csv) {
  const plats = [];
  for (const ligne of csv.split(/\r?\n/)) {
    const [id, kcal, masse] = ligne.split(',');
    const k = Number(kcal);
    const g = Number(masse);
    if (!/^dish_\d+$/.test(id) || !(k >= 50 && k <= 1500) || !(g >= 80 && g <= 900)) continue;
    plats.push({ id, kcal: Math.round(k), grammes: Math.round(g) });
  }
  return plats;
}

// Mélange reproductible (mulberry32).
export function melanger(liste, graineNum) {
  let a = graineNum >>> 0;
  const alea = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const r = [...liste];
  for (let i = r.length - 1; i > 0; i--) {
    const j = Math.floor(alea() * (i + 1));
    [r[i], r[j]] = [r[j], r[i]];
  }
  return r;
}

if (process.argv[1].endsWith('importer_nutrition5k.mjs')) {
  if (!dossier) {
    console.error('Usage : node eval/importer_nutrition5k.mjs <dossier> [nombre] [graine]');
    process.exit(1);
  }
  mkdirSync(dossier, { recursive: true });
  const csv = (await Promise.all(
    ['cafe1', 'cafe2'].map((c) => fetch(`${BASE}/metadata/dish_metadata_${c}.csv`).then((r) => r.text())),
  )).join('\n');
  const tirage = melanger(lirePlats(csv), Number(graine)).slice(0, Number(n) * 2);
  let fait = 0;
  for (const p of tirage) {
    if (fait >= Number(n)) break;
    const r = await fetch(`${BASE}/imagery/realsense_overhead/${p.id}/rgb.png`);
    if (!r.ok) continue;
    const png = join(dossier, `${p.id}.png`);
    writeFileSync(png, Buffer.from(await r.arrayBuffer()));
    execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', png, '-vf', 'scale=1024:-2', '-q:v', '3', join(dossier, `${p.id}.jpg`)]);
    writeFileSync(
      join(dossier, `${p.id}.json`),
      JSON.stringify({ kcal: p.kcal, grammes: p.grammes, source: 'Nutrition5k (CC BY 4.0)' }),
    );
    (await import('node:fs')).unlinkSync(png);
    fait++;
    if (fait % 10 === 0) console.log(`${fait}/${n}`);
  }
  console.log(`${fait} plats prêts dans ${dossier}`);
}
