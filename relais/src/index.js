import { analyse, entreeModele } from './analyse.js';
import { clesGoogle, JetonInvalide, verifierJeton } from './jeton.js';
import { consommer } from './limites.js';

const TAILLE_MAX = 1_500_000;

const reponse = (corps, statut = 200) =>
  new Response(JSON.stringify(corps), {
    status: statut,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

/**
 * POST /analyse — corps : image JPEG ; en-tête Authorization: Bearer <jeton
 * Firebase>. Réponse : {"aliments":[…]} ou {"erreur":"auth|quota|taille|illisible|ia"}.
 * L'image n'est ni enregistrée ni journalisée.
 */
export async function traiter(request, env, deps = {}) {
  const url = new URL(request.url);
  if (url.pathname !== '/analyse') return reponse({ erreur: 'introuvable' }, 404);
  if (request.method !== 'POST') return reponse({ erreur: 'méthode' }, 405);

  let uid;
  try {
    const entete = request.headers.get('authorization') ?? '';
    uid = await verifierJeton(entete.replace(/^Bearer\s+/i, ''), {
      projectId: env.PROJECT_ID,
      cles: deps.cles ?? clesGoogle,
      maintenant: deps.maintenant,
    });
  } catch (e) {
    if (e instanceof JetonInvalide) return reponse({ erreur: 'auth' }, 401);
    return reponse({ erreur: 'ia' }, 502);
  }

  const octets = new Uint8Array(await request.arrayBuffer());
  if (octets.length === 0 || octets.length > TAILLE_MAX) {
    return reponse({ erreur: 'taille' }, 413);
  }

  const limite = await consommer(env.LIMITES, uid, {
    plafondUtilisateur: Number(env.PLAFOND_UTILISATEUR ?? 15),
    plafondGlobal: Number(env.PLAFOND_GLOBAL ?? 150),
    maintenant: deps.maintenant,
  });
  if (!limite.ok) return reponse({ erreur: 'quota', raison: limite.raison }, 429);

  let sortie;
  try {
    const brut = await env.AI.run(
      env.MODELE,
      entreeModele(octets, url.searchParams.get('indice') ?? ''),
    );
    sortie = analyse(brut?.response ?? brut);
  } catch {
    return reponse({ erreur: 'ia' }, 502);
  }
  if (sortie === null) return reponse({ erreur: 'illisible' }, 422);
  return reponse(sortie);
}

export default {
  fetch: (request, env) => traiter(request, env),
};
