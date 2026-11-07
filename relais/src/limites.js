// Plafonds journaliers (UTC). KV n'est pas atomique : N requêtes simultanées
// peuvent lire la même valeur et passer toutes, soit jusqu'à N-1 analyses de
// plus que le plafond par rafale (le compteur, lui, n'avance que d'une unité).
// Une limite stricte demande un Durable Object ou D1 (décision en attente).

const TTL = { expirationTtl: 172_800 };

export function jourUtc(maintenant = Date.now()) {
  return new Date(maintenant).toISOString().slice(0, 10);
}

const cles = (uid, jour) => ({ cleG: `g:${jour}`, cleU: `u:${uid}:${jour}` });

async function compter(kv, cle, plafond) {
  const n = Number((await kv.get(cle)) ?? 0);
  return { n, ok: n < plafond };
}

/**
 * Vérifie puis consomme une unité pour l'utilisateur et pour le global.
 * Les erreurs de KV (limite d'écriture par clé, quota du plan gratuit)
 * remontent : l'appelant répond alors en JSON.
 * @returns {Promise<{ok: true, jour: string, restantes: number} | {ok: false, raison: 'utilisateur' | 'global'}>}
 */
export async function consommer(kv, uid, { plafondUtilisateur, plafondGlobal, maintenant = Date.now() }) {
  const jour = jourUtc(maintenant);
  const { cleG, cleU } = cles(uid, jour);
  const g = await compter(kv, cleG, plafondGlobal);
  if (!g.ok) return { ok: false, raison: 'global' };
  const u = await compter(kv, cleU, plafondUtilisateur);
  if (!u.ok) return { ok: false, raison: 'utilisateur' };
  await kv.put(cleG, String(g.n + 1), TTL);
  await kv.put(cleU, String(u.n + 1), TTL);
  return { ok: true, jour, restantes: Math.max(0, plafondUtilisateur - (u.n + 1)) };
}

/**
 * Rend l'unité prise par [consommer] quand aucune réponse exploitable n'a été
 * produite (panne, réponse illisible, délai dépassé) : les deux compteurs
 * reculent d'une unité, sans descendre sous 0. Ne lève jamais.
 */
export async function rendre(kv, uid, jour) {
  const { cleG, cleU } = cles(uid, jour);
  for (const cle of [cleG, cleU]) {
    try {
      const n = Number((await kv.get(cle)) ?? 0);
      if (n > 0) await kv.put(cle, String(n - 1), TTL);
    } catch {
      console.log('limites : unité non rendue (erreur KV)');
    }
  }
}
