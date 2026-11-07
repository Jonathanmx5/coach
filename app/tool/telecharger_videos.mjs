// Récupère les vidéos de démonstration de wger (https://wger.de, licence
// CC BY-SA 4.0, auteur « Goulart ») pour les exercices qui en ont une, et les
// range dans assets/videos/ : 6 secondes, 720 px de large, H.264 sans son.
// Les extraits ainsi raccourcis restent sous CC BY-SA 4.0 (crédit dans
// « Sources et licences » et le README). ffmpeg doit être dans le PATH.
// Usage : node tool/telecharger_videos.mjs
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SORTIE = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'videos');

/** Exercice de l'application -> vidéo wger et début de l'extrait (s). */
const CORRESPONDANCE = {
  developpe_couche: { url: 'https://wger.de/media/exercise-video/73/2bdb390c-312c-4497-a722-5eed2c823e5a.MOV', debut: 1 },
  developpe_halteres: { url: 'https://wger.de/media/exercise-video/75/080c799b-8afd-4130-8d72-9cef0cd79f54.MOV', debut: 1 },
  fentes_halteres: { url: 'https://wger.de/media/exercise-video/205/c167ac34-ddbc-4e1b-8edf-1192e9d00e22.MOV', debut: 2 },
  presse_cuisses: { url: 'https://wger.de/media/exercise-video/371/6aae16b4-01b9-4eb4-935c-3250f84d2c59.MOV', debut: 4 },
  souleve_terre_halteres: { url: 'https://wger.de/media/exercise-video/507/307e7276-a14d-4ea0-b579-f5b0dbc6f5af.MOV', debut: 1 },
  elevations_laterales: { url: 'https://wger.de/media/exercise-video/348/de69928a-8a35-4096-821c-1f46de5e0e03.MOV', debut: 0 },
  developpe_epaules: { url: 'https://wger.de/media/exercise-video/567/64f33c19-1d96-4b7c-af17-6c6a4941c614.MOV', debut: 1 },
  developpe_incline_halteres: { url: 'https://wger.de/media/exercise-video/537/b9c937e9-daeb-42a9-be8e-7a77e368478c.MOV', debut: 0 },
  extension_triceps: { url: 'https://wger.de/media/exercise-video/211/85f6eb25-a76c-409e-9af9-497794ac0dfb.MOV', debut: 0 },
  kickback_triceps: { url: 'https://wger.de/media/exercise-video/655/2d88a05b-bde3-4026-bfbf-524c11068dc5.MOV', debut: 0 },
  curl_biceps: { url: 'https://wger.de/media/exercise-video/92/8bfb917c-3d0d-49b9-8073-5d7e01c1b894.MOV', debut: 0 },
  curl_marteau: { url: 'https://wger.de/media/exercise-video/272/df069052-2173-4f24-855f-a0eebe729f24.MOV', debut: 0 },
  oiseau: { url: 'https://wger.de/media/exercise-video/82/28b53647-27e7-47cf-8852-2ee666c8b628.MOV', debut: 0 },
  rowing_assis: { url: 'https://wger.de/media/exercise-video/512/fff4c294-93f0-4926-b3a2-bf59ad4afaa5.MOV', debut: 0 },
  face_pull: { url: 'https://wger.de/media/exercise-video/222/eea93fcc-6a3c-4783-8f70-0234c791a001.MOV', debut: 0 },
  leg_curl: { url: 'https://wger.de/media/exercise-video/365/becaf013-5044-40d0-bae9-7ed60c973737.MOV', debut: 0 },
  dips_barres: { url: 'https://wger.de/media/exercise-video/194/dd9a663f-d8ba-4621-823b-13788ccb66bc.MOV', debut: 0 },
  extension_triceps_poulie: { url: 'https://wger.de/media/exercise-video/659/1f2eb3b6-3185-429f-8330-26dc88f39aff.MOV', debut: 0 },
};

mkdirSync(SORTIE, { recursive: true });
const travail = mkdtempSync(join(tmpdir(), 'videos-'));
try {
  for (const [id, { url, debut }] of Object.entries(CORRESPONDANCE)) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`${id} : HTTP ${r.status}`);
    const brut = join(travail, `${id}.mov`);
    writeFileSync(brut, Buffer.from(await r.arrayBuffer()));
    execFileSync('ffmpeg', [
      '-v', 'error', '-y', '-ss', String(debut), '-t', '6', '-i', brut,
      '-an', '-vf', 'scale=720:-2,fps=30',
      '-c:v', 'libx264', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
      '-crf', '28', '-preset', 'slow', '-movflags', '+faststart',
      join(SORTIE, `${id}.mp4`),
    ]);
    console.log(id, 'ok');
  }
} finally {
  rmSync(travail, { recursive: true, force: true });
}
