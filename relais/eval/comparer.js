// Compare plusieurs modèles sur un jeu de photos de repas pesés.
//
//   node eval/comparer.js ./photos [modele1,modele2,…]
//
// Dossier : x.jpg + x.json  {"kcal": 650, "grammes": 480}  (grammes facultatif :
// poids total pesé du repas). Les modèles par défaut sont ceux de Workers AI ;
// « gemini » s'ajoute si GEMINI_API_KEY est défini dans l'environnement.
// Le worker d'évaluation est lancé en local (wrangler dev --remote) : il utilise
// le quota gratuit de Workers AI, sans jeton ni plafond.
import { spawn } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dansLaFourchette, pourcent, resumer } from './metriques.js';

const ici = dirname(fileURLToPath(import.meta.url));
const dossier = process.argv[2];
const PAR_DEFAUT = [
  '@cf/meta/llama-3.2-11b-vision-instruct',
  '@cf/meta/llama-4-scout-17b-16e-instruct',
  '@cf/mistralai/mistral-small-3.1-24b-instruct',
];
if (!dossier) {
  console.error('Usage : node eval/comparer.js <dossier de photos> [modele1,modele2,…]');
  process.exit(1);
}
const modeles = process.argv[3]
  ? process.argv[3].split(',')
  : [...PAR_DEFAUT, ...(process.env.GEMINI_API_KEY ? ['gemini'] : [])];

const photos = readdirSync(dossier)
  .filter((n) => n.toLowerCase().endsWith('.jpg'))
  .map((n) => ({ nom: n, ref: JSON.parse(readFileSync(join(dossier, n.replace(/\.jpg$/i, '.json')), 'utf8')) }));
if (photos.length === 0) {
  console.error('Aucune photo .jpg dans', dossier);
  process.exit(1);
}

const args = ['wrangler', 'dev', '--remote', '-c', join(ici, 'wrangler.toml'), '--port', '8799'];
if (process.env.GEMINI_API_KEY) args.push('--var', `GEMINI_API_KEY:${process.env.GEMINI_API_KEY}`);
const serveur = spawn('npx', args, { shell: true, stdio: ['ignore', 'pipe', 'pipe'] });
await new Promise((ok, ko) => {
  const t = setTimeout(() => ko(new Error('le worker ne démarre pas')), 120_000);
  const vu = (d) => {
    if (String(d).includes('Ready on')) {
      clearTimeout(t);
      ok();
    }
  };
  serveur.stdout.on('data', vu);
  serveur.stderr.on('data', vu);
});

const parModele = {};
try {
  for (const m of modeles) {
    parModele[m] = [];
    for (const p of photos) {
      const t0 = Date.now();
      let ligne;
      try {
        const r = await fetch(`http://127.0.0.1:8799/?m=${encodeURIComponent(m)}`, {
          method: 'POST',
          body: readFileSync(join(dossier, p.nom)),
          signal: AbortSignal.timeout(120_000),
        });
        const j = await r.json();
        const aliments = j.analyse?.aliments;
        if (r.ok && Array.isArray(aliments) && aliments.length > 0) {
          ligne = {
            ok: true,
            ms: j.ms,
            kcalEstime: aliments.reduce((s, a) => s + a.kcal, 0),
            kcalRef: p.ref.kcal,
            grammesEstime: aliments.reduce((s, a) => s + a.grammes, 0),
            grammesRef: p.ref.grammes,
            dansFourchette: p.ref.grammes ? dansLaFourchette(aliments, p.ref.grammes) : undefined,
          };
        } else {
          ligne = { ok: false, ms: Date.now() - t0 };
        }
      } catch {
        ligne = { ok: false, ms: Date.now() - t0 };
      }
      parModele[m].push(ligne);
      console.log(`${m.split('/').pop()} · ${p.nom} : ${ligne.ok ? `${ligne.kcalEstime} kcal (réf. ${p.ref.kcal})` : 'illisible'}`);
    }
  }
} finally {
  serveur.kill();
  spawn('taskkill', ['/F', '/T', '/PID', String(serveur.pid)], { shell: true, stdio: 'ignore' });
}

console.log(`\n=== Résumé (${photos.length} photos) ===`);
console.log('modèle | lisibles | erreur kcal médiane | dans ±20 % | erreur poids médiane | fourchette juste | durée');
for (const [m, essais] of Object.entries(parModele)) {
  const r = resumer(essais);
  console.log(
    [
      m.split('/').pop(),
      `${r.lisibles}/${r.photos}`,
      pourcent(r.ecartKcalMedian),
      pourcent(r.dans20pc),
      pourcent(r.ecartGrammesMedian),
      pourcent(r.fourchetteJuste),
      r.dureeMoyenneMs === null ? '—' : `${Math.round(r.dureeMoyenneMs / 1000)} s`,
    ].join(' | '),
  );
}
