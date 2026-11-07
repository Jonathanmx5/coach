// Ciqual 2020 (ANSES) -> tableau compact pour le relais (donnees/ciqual.json).
// Fichier source : « Table Ciqual 2020 » au format XLS, sur
// https://ciqual.anses.fr ou https://doi.org/10.5281/zenodo.4770600.
// Garde, pour chaque aliment, l'énergie et les macronutriments pour 100 g
// (« traces » et « < x » comptent pour 0 ; aliments incomplets écartés).
//   npm install --no-save xlsx@0.18.5
//   node outils/convertir_ciqual.cjs ciqual2020.xls donnees/ciqual.json
const XLSX = require('xlsx');
const fs = require('fs');
const wb = XLSX.readFile(process.argv[2]);
const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, raw: false });
const tete = rows[0];
const col = (n) => { const i = tete.indexOf(n); if (i < 0) throw new Error(n); return i; };
const C = {
  code: col('alim_code'), nom: col('alim_nom_fr'), grp: col('alim_grp_nom_fr'), ssgrp: col('alim_ssgrp_nom_fr'),
  kcal: col('Energie, Règlement UE N° 1169/2011 (kcal/100 g)'),
  kcalJ: col('Energie, N x facteur Jones, avec fibres  (kcal/100 g)'),
  p: col('Protéines, N x facteur de Jones (g/100 g)'), p2: col('Protéines, N x 6.25 (g/100 g)'),
  g: col('Glucides (g/100 g)'), s: col('Sucres (g/100 g)'), l: col('Lipides (g/100 g)'),
  sat: col('AG saturés (g/100 g)'), alc: col('Alcool (g/100 g)'),
};
const val = (v) => {
  if (v == null) return null;
  const t = String(v).trim().toLowerCase();
  if (t === '' || t === '-') return null;
  if (t === 'traces' || t.startsWith('<')) return 0;
  const n = Number.parseFloat(t.replace(',', '.'));
  return Number.isFinite(n) ? n : null;
};
const r1 = (n) => (n == null ? null : Math.round(n * 10) / 10);
const sortie = [];
for (const row of rows.slice(1)) {
  const nom = (row[C.nom] ?? '').trim();
  if (!nom) continue;
  const p = val(row[C.p]) ?? val(row[C.p2]);
  const g = val(row[C.g]);
  const l = val(row[C.l]);
  let kcal = val(row[C.kcal]) ?? val(row[C.kcalJ]);
  if (kcal == null && p != null && g != null && l != null) kcal = p * 4 + g * 4 + l * 9 + (val(row[C.alc]) ?? 0) * 7;
  if (kcal == null || p == null || g == null || l == null) continue;
  sortie.push([row[C.code], nom, (row[C.ssgrp] && row[C.ssgrp] !== '-' ? row[C.ssgrp] : row[C.grp]) ?? '', Math.round(kcal), r1(p), r1(g), r1(val(row[C.s])), r1(l), r1(val(row[C.sat]))]);
}
const doc = {
  source: 'ANSES. 2020. Table de composition nutritionnelle des aliments Ciqual. https://doi.org/10.5281/zenodo.4770600 (CC BY 4.0)',
  colonnes: ['code', 'nom', 'groupe', 'kcal', 'proteines', 'glucides', 'sucres', 'lipides', 'satures'],
  unite: 'pour 100 g',
  aliments: sortie,
};
fs.writeFileSync(process.argv[3], JSON.stringify(doc));
console.log(sortie.length, 'aliments,', fs.statSync(process.argv[3]).size, 'octets');
