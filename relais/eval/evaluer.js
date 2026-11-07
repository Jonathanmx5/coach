// Mesure la qualité du relais déployé sur un jeu de photos.
// Usage : RELAIS_URL=https://… JETON=<jeton Firebase> node eval/evaluer.js ./photos
// Chaque photo x.jpg a un x.json {"kcal": 650} (valeur de référence, ex. pesée).
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dossier = process.argv[2];
const { RELAIS_URL, JETON } = process.env;
if (!dossier || !RELAIS_URL || !JETON) {
  console.error('Usage : RELAIS_URL=… JETON=… node eval/evaluer.js <dossier>');
  process.exit(1);
}

const erreurs = [];
for (const f of readdirSync(dossier).filter((n) => n.endsWith('.jpg'))) {
  const attendu = JSON.parse(readFileSync(join(dossier, f.replace('.jpg', '.json')), 'utf8')).kcal;
  const r = await fetch(`${RELAIS_URL}/analyse`, {
    method: 'POST',
    headers: { authorization: `Bearer ${JETON}` },
    body: readFileSync(join(dossier, f)),
  });
  if (!r.ok) {
    console.log(`${f}: HTTP ${r.status}`);
    continue;
  }
  const { aliments } = await r.json();
  const estime = aliments.reduce((s, a) => s + a.kcal, 0);
  const ecart = Math.abs(estime - attendu) / attendu;
  erreurs.push(ecart);
  console.log(`${f}: attendu ${attendu}, estimé ${estime} (${Math.round(ecart * 100)} %)`);
}
if (erreurs.length) {
  erreurs.sort((a, b) => a - b);
  const moyenne = erreurs.reduce((a, b) => a + b, 0) / erreurs.length;
  console.log(`\n${erreurs.length} photos — erreur moyenne ${Math.round(moyenne * 100)} %, médiane ${Math.round(erreurs[Math.floor(erreurs.length / 2)] * 100)} %`);
}
