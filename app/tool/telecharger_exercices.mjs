// Récupère les deux photos (début et fin du mouvement) de chaque exercice dans
// « free-exercise-db » (https://github.com/yuhonas/free-exercise-db, licence
// Unlicense : domaine public) et les range dans assets/exercices/ en JPEG
// 720 × 480, recadrées pour remplir le cadre (taille d'origine : 850 × 567). ffmpeg doit être dans le PATH.
// Usage : node tool/telecharger_exercices.mjs
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';
const SORTIE = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'exercices');

/**
 * Exercice de l'application -> dossier dans free-exercise-db. Chaque paire a
 * été vérifiée à l'œil : bon mouvement, deux positions différentes, pas de
 * partenaire ni de matériel absent de la consigne.
 */
const CORRESPONDANCE = {
  // Séance : jambes
  squat: 'Bodyweight_Squat',
  squat_halteres: 'Dumbbell_Squat',
  presse_cuisses: 'Leg_Press',
  fentes: 'Bodyweight_Walking_Lunge',
  fentes_halteres: 'Dumbbell_Lunges',
  pont_fessier: 'Butt_Lift_Bridge',
  pont_unijambiste: 'Single_Leg_Glute_Bridge',
  kickback_fessier: 'Glute_Kickback',
  squat_saute: 'Rocket_Jump',
  souleve_terre_halteres: 'Stiff-Legged_Dumbbell_Deadlift',
  swing_kettlebell: 'One-Arm_Kettlebell_Swings',
  // Pousser
  pompes_genoux: 'Incline_Push-Up',
  pompes: 'Pushups',
  pompes_serrees: 'Push-Ups_-_Close_Triceps_Position',
  developpe_halteres: 'Dumbbell_Bench_Press',
  developpe_couche: 'Barbell_Bench_Press_-_Medium_Grip',
  dips_chaise: 'Bench_Dips',
  // Tirer
  superman: 'Superman',
  tirage_elastique: 'Band_Pull_Apart',
  rowing_halteres: 'Bent_Over_Two-Dumbbell_Row',
  tractions: 'Pullups',
  tirage_vertical: 'Wide-Grip_Lat_Pulldown',
  // Tronc
  planche: 'Plank',
  gainage_lateral: 'Side_Bridge',
  crunch: 'Crunches',
  crunch_inverse: 'Reverse_Crunch',
  crunch_croise: 'Cross-Body_Crunch',
  dead_bug: 'Dead_Bug',
  battements_jambes: 'Scissor_Kick',
  velo_abdos: 'Air_Bike',
  rotation_russe: 'Russian_Twist',
  // Cardio
  corde: 'Rope_Jumping',
  mountain_climbers: 'Mountain_Climbers',
  jumping_jacks: 'Star_Jump',
  montees_genoux: 'Fast_Skipping',
  marche_genoux: 'Step-up_with_Knee_Raise',
  talons_fesses: 'Double_Leg_Butt_Kick',
  // Séance avec haltères ou en salle
  elevations_laterales: 'Side_Lateral_Raise',
  developpe_epaules: 'Dumbbell_Shoulder_Press',
  developpe_incline_halteres: 'Incline_Dumbbell_Press',
  extension_triceps: 'Seated_Triceps_Press',
  kickback_triceps: 'Tricep_Dumbbell_Kickback',
  curl_biceps: 'Dumbbell_Bicep_Curl',
  curl_marteau: 'Hammer_Curls',
  oiseau: 'Seated_Bent-Over_Rear_Delt_Raise',
  rowing_assis: 'Seated_Cable_Rows',
  face_pull: 'Face_Pull',
  leg_curl: 'Lying_Leg_Curls',
  dips_barres: 'Dips_-_Triceps_Version',
  extension_triceps_poulie: 'Cable_Rope_Overhead_Triceps_Extension',
  // Étirements et mobilité
  etir_quadriceps: 'Standing_Elevated_Quad_Stretch',
  etir_ischios: 'Seated_Floor_Hamstring_Stretch',
  etir_fessiers: 'Ankle_On_The_Knee',
  etir_mollets: 'Calf_Stretch_Hands_Against_Wall',
  etir_pectoraux: 'One_Arm_Against_Wall',
  etir_epaules: 'Shoulder_Stretch',
  posture_enfant: 'Childs_Pose',
  cercles_nuque: 'Side_Neck_Stretch',
  cercles_epaules: 'Arm_Circles',
  chat_vache: 'Cat_Stretch',
  rotation_buste: 'Spinal_Stretch',
  fente_basse: 'Kneeling_Hip_Flexor',
  squat_profond: 'Sit_Squats',
  genoux_poitrine: 'Hug_Knees_To_Chest',
  torsion_allongee: 'Side-Lying_Floor_Stretch',
};

const travail = mkdtempSync(join(tmpdir(), 'exercices-'));
try {
  for (const [id, dossier] of Object.entries(CORRESPONDANCE)) {
    for (let i = 0; i < 2; i++) {
      const r = await fetch(`${BASE}/${encodeURIComponent(dossier)}/${i}.jpg`);
      if (!r.ok) throw new Error(`${id} ${i} : HTTP ${r.status}`);
      const brut = join(travail, `${id}_${i}.jpg`);
      writeFileSync(brut, Buffer.from(await r.arrayBuffer()));
      execFileSync('ffmpeg', [
        '-v', 'error', '-y', '-i', brut,
        '-vf', 'scale=720:480:force_original_aspect_ratio=increase,crop=720:480',
        '-q:v', '4',
        join(SORTIE, `${id}_${i}.jpg`),
      ]);
    }
    console.log(id, 'ok');
  }
} finally {
  rmSync(travail, { recursive: true, force: true });
}
