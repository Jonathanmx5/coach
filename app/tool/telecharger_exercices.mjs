// Récupère les deux photos (début et fin du mouvement) de chaque exercice dans
// « free-exercise-db » (https://github.com/yuhonas/free-exercise-db, licence
// Unlicense : domaine public). Les images sont ensuite réduites et rangées dans
// assets/exercices/. Usage : node tool/telecharger_exercices.mjs <dossier de travail>
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main';

/** Exercice de l'application -> nom dans free-exercise-db. */
const CORRESPONDANCE = {
  squat: 'Bodyweight Squat',
  squat_halteres: 'Dumbbell Squat',
  presse_cuisses: 'Leg Press',
  fentes: 'Bodyweight Walking Lunge',
  fentes_halteres: 'Dumbbell Lunges',
  pont_fessier: 'Butt Lift (Bridge)',
  souleve_terre_halteres: 'Stiff-Legged Dumbbell Deadlift',
  swing_kettlebell: 'One-Arm Kettlebell Swings',
  pompes_genoux: 'Pushups',
  pompes: 'Pushups',
  developpe_halteres: 'Dumbbell Bench Press',
  developpe_couche: 'Barbell Bench Press - Medium Grip',
  dips_chaise: 'Bench Dips',
  superman: 'Superman',
  tirage_elastique: 'Seated Cable Rows',
  rowing_halteres: 'Bent Over Two-Dumbbell Row',
  tractions: 'Pullups',
  tirage_vertical: 'Wide-Grip Lat Pulldown',
  planche: 'Plank',
  gainage_lateral: 'Side Bridge',
  crunch: 'Crunches',
  dead_bug: 'Dead Bug',
  corde: 'Rope Jumping',
  montees_genoux: 'Fast Skipping',
};

const dossier = process.argv[2];
if (!dossier) {
  console.error('Usage : node tool/telecharger_exercices.mjs <dossier de travail>');
  process.exit(1);
}
mkdirSync(dossier, { recursive: true });
const liste = JSON.parse(readFileSync(join(dossier, 'exercises.json'), 'utf8'));

for (const [id, nom] of Object.entries(CORRESPONDANCE)) {
  const e = liste.find((x) => x.name === nom);
  if (!e || !e.images || e.images.length < 2) {
    console.log(id, 'ABSENT', nom);
    continue;
  }
  for (let i = 0; i < 2; i++) {
    const url = `${BASE}/exercises/${e.images[i].split('/').map(encodeURIComponent).join('/')}`;
    const r = await fetch(url);
    if (!r.ok) {
      console.log(id, i, 'HTTP', r.status, url);
      continue;
    }
    writeFileSync(join(dossier, `${id}_${i}.jpg`), Buffer.from(await r.arrayBuffer()));
  }
  console.log(id, 'ok');
}
