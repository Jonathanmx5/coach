import { analyse, entreeModele } from './analyse.js';
import { clesAppCheck, clesGoogle, JetonInvalide, verifierAppCheck, verifierJeton } from './jeton.js';
import { appelerGemini, DELAI_GEMINI } from './gemini.js';
import { consommer, rendre } from './limites.js';

const TAILLE_MAX = 1_500_000;
// Enveloppe d'un envoi multipart : frontières, en-têtes des parties et
// précision (200 caractères utiles au plus).
const MARGE_MULTIPART = 16_384;
// Temps total accordé aux modèles : l'application abandonne au bout de 45 s.
export const BUDGET_MS = 35_000;
// En dessous, le modèle de secours n'a pas le temps de répondre : on s'arrête.
export const MINIMUM_SECOURS_MS = 12_000;

const reponse = (corps, statut = 200) =>
  new Response(JSON.stringify(corps), {
    status: statut,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

/** Octets magiques d'un JPEG (FF D8 FF) : l'application ré-encode toujours en JPEG. */
export const estJpeg = (o) => o.length >= 3 && o[0] === 0xff && o[1] === 0xd8 && o[2] === 0xff;

/** Workers AI : quota de neurones du compte épuisé (erreur 3036 ou 4006). */
export function quotaWorkersEpuise(e) {
  return /\b(3036|4006)\b|free allocation|used up your daily/i.test(String(e?.message ?? e ?? ''));
}

class DelaiDepasse extends Error {
  name = 'TimeoutError';
}

function avecDelai(promesse, ms) {
  let minuteur;
  const delai = new Promise((_, rejeter) => {
    minuteur = setTimeout(() => rejeter(new DelaiDepasse('délai dépassé')), Math.max(0, ms));
  });
  return Promise.race([promesse, delai]).finally(() => clearTimeout(minuteur));
}

/** Tâche à finir après la réponse (ctx.waitUntil), ou tout de suite sans contexte (tests). */
const differer = (ctx, promesse) => (ctx?.waitUntil ? ctx.waitUntil(promesse) : promesse);

/**
 * Lit l'image et la précision. Deux formats : multipart/form-data (parties
 * `image` et `indice`, celui de l'application) et l'ancien corps brut avec
 * `?indice=` dans l'adresse (applications pas encore à jour).
 * @returns {Promise<{octets: Uint8Array, indice: string} | {erreur: 'format'}>}
 */
async function lireEntree(request, url) {
  const type = request.headers.get('content-type') ?? '';
  if (/^multipart\/form-data/i.test(type)) {
    let formulaire;
    try {
      formulaire = await request.formData();
    } catch {
      return { erreur: 'format' };
    }
    const image = formulaire.get('image');
    if (image === null || typeof image === 'string') return { erreur: 'format' };
    const indice = formulaire.get('indice');
    return {
      octets: new Uint8Array(await image.arrayBuffer()),
      indice: typeof indice === 'string' ? indice : '',
    };
  }
  return {
    octets: new Uint8Array(await request.arrayBuffer()),
    indice: url.searchParams.get('indice') ?? '',
  };
}

/**
 * POST /analyse — corps : multipart/form-data (parties `image` en JPEG et
 * `indice` facultative) ou image JPEG brute ; en-tête Authorization: Bearer
 * <jeton Firebase>. Réponse : {"aliments":[…],"restantes":n} ou
 * {"erreur":"auth|quota|taille|format|illisible|ia"}. Ne lève jamais : une
 * erreur imprévue donne {"erreur":"ia"} en 503.
 * L'image et la précision ne sont ni enregistrées ni journalisées.
 */
export async function traiter(request, env, deps = {}) {
  try {
    return await executer(request, env, deps);
  } catch (e) {
    console.log(`relais : erreur imprévue (${e?.name ?? 'inconnue'})`);
    return reponse({ erreur: 'ia' }, 503);
  }
}

async function executer(request, env, deps) {
  const horloge = deps.horloge ?? Date.now;
  const debut = horloge();
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

  // App Check : « off » ne regarde rien, « observe » note les appels sans
  // preuve dans les journaux, « enforce » les refuse. Les APK installés hors
  // Play Store n'ont pas de preuve : « enforce » attend le Play Store.
  const modeAppCheck = env.APP_CHECK ?? 'off';
  if (modeAppCheck !== 'off') {
    let prouve = false;
    try {
      await verifierAppCheck(request.headers.get('x-firebase-appcheck') ?? '', {
        projectId: env.PROJECT_ID,
        projectNumber: env.PROJECT_NUMBER,
        cles: deps.clesAppCheck ?? clesAppCheck,
        maintenant: deps.maintenant,
      });
      prouve = true;
    } catch {
      // jeton absent, invalide, ou clés injoignables : même traitement
    }
    if (!prouve) {
      if (modeAppCheck === 'enforce') return reponse({ erreur: 'auth' }, 401);
      console.log('appcheck: appel sans preuve valide');
    }
  }

  // Contrôles d'entrée, tous avant de toucher au quota. Un corps annoncé trop
  // gros est refusé sans être lu.
  if (Number(request.headers.get('content-length')) > TAILLE_MAX + MARGE_MULTIPART) {
    return reponse({ erreur: 'taille' }, 413);
  }
  const entree = await lireEntree(request, url);
  if (entree.erreur) return reponse({ erreur: 'format' }, 415);
  const { octets, indice } = entree;
  if (octets.length === 0 || octets.length > TAILLE_MAX) {
    return reponse({ erreur: 'taille' }, 413);
  }
  if (!estJpeg(octets)) return reponse({ erreur: 'format' }, 415);

  let limite;
  try {
    limite = await consommer(env.LIMITES, uid, {
      plafondUtilisateur: Number(env.PLAFOND_UTILISATEUR ?? 8),
      plafondGlobal: Number(env.PLAFOND_GLOBAL ?? 150),
      maintenant: deps.maintenant,
    });
  } catch {
    // Limite d'écriture par clé ou quota d'écritures du plan gratuit.
    console.log('limites : KV indisponible');
    return reponse({ erreur: 'ia' }, 503);
  }
  if (!limite.ok) return reponse({ erreur: 'quota', raison: limite.raison }, 429);

  // L'unité prise est rendue si aucune réponse exploitable n'est produite
  // (panne, réponse illisible, délai dépassé, erreur imprévue).
  const essais = [];
  let resultat = null;
  try {
    resultat = await interroger(octets, indice, env, deps, () => BUDGET_MS - (horloge() - debut), essais);
    return resultat.statut === 200
      ? reponse({ ...resultat.corps, restantes: limite.restantes })
      : reponse(resultat.corps, resultat.statut);
  } finally {
    // Usage par requête : modèles appelés et jetons, jamais l'image, la
    // précision ni l'utilisateur.
    console.log(JSON.stringify({ analyse: resultat?.statut ?? 'erreur', ms: horloge() - debut, essais }));
    if (resultat?.statut !== 200) await differer(deps.ctx, rendre(env.LIMITES, uid, limite.jour));
  }
}

/**
 * Gemini d'abord quand une clé est configurée ; au moindre échec (clé
 * refusée, quota, panne, délai, réponse coupée ou illisible), le modèle
 * principal de Workers AI, puis le modèle de secours s'il reste assez de temps.
 * @returns {Promise<{statut: number, corps: object}>}
 */
async function interroger(octets, indice, env, deps, reste, essais) {
  let sortie = null;
  if (env.GEMINI_API_KEY && (env.FOURNISSEUR ?? 'gemini') !== 'workers') {
    const modele = env.GEMINI_MODELE ?? 'gemini-3.8-flash';
    const essai = { modele };
    essais.push(essai);
    try {
      sortie = analyse(
        await appelerGemini(octets, indice, {
          cle: env.GEMINI_API_KEY,
          modele,
          fetcher: deps.fetcher,
          delai: Math.min(DELAI_GEMINI, reste()),
          surUsage: (u) => Object.assign(essai, u),
        }),
      );
      essai.ok = sortie !== null;
    } catch (e) {
      essai.ok = false;
      essai.erreur = e?.name === 'TimeoutError' ? 'delai' : 'echec';
    }
  }

  let erreurIa = false;
  let quotaService = false;
  const modeles = [env.MODELE, env.MODELE_SECOURS];
  for (let i = 0; i < modeles.length && sortie === null; i++) {
    const modele = modeles[i];
    if (!modele) continue;
    if (i === 1 && reste() < MINIMUM_SECOURS_MS) {
      essais.push({ modele, saute: 'delai' });
      break;
    }
    const essai = { modele };
    essais.push(essai);
    try {
      const brut = await avecDelai(env.AI.run(modele, entreeModele(octets, indice)), reste());
      if (brut?.usage) {
        essai.entree = brut.usage.prompt_tokens ?? null;
        essai.sortie = brut.usage.completion_tokens ?? null;
      }
      sortie = analyse(brut?.response ?? brut?.choices?.[0]?.message?.content ?? brut);
      essai.ok = sortie !== null;
      erreurIa = false;
    } catch (e) {
      essai.ok = false;
      if (quotaWorkersEpuise(e)) {
        // Le secours puise dans le même quota : inutile d'insister.
        essai.erreur = 'quota';
        quotaService = true;
        break;
      }
      essai.erreur = e?.name === 'TimeoutError' ? 'delai' : 'echec';
      erreurIa = true;
    }
  }
  if (sortie !== null) return { statut: 200, corps: sortie };
  if (quotaService) return { statut: 429, corps: { erreur: 'quota', raison: 'service' } };
  if (erreurIa) return { statut: 502, corps: { erreur: 'ia' } };
  return { statut: 422, corps: { erreur: 'illisible' } };
}

export default {
  fetch: (request, env, ctx) => traiter(request, env, { ctx }),
};
