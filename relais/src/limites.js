// Plafonds journaliers (UTC). KV n'est pas atomique : deux requêtes simultanées
// peuvent dépasser d'une unité, ce qui suffit pour protéger un quota gratuit.

export function jourUtc(maintenant = Date.now()) {
  return new Date(maintenant).toISOString().slice(0, 10);
}

async function compter(kv, cle, plafond) {
  const n = Number((await kv.get(cle)) ?? 0);
  return { n, ok: n < plafond };
}

/**
 * Vérifie puis consomme une unité pour l'utilisateur et pour le global.
 * @returns {Promise<{ok: true} | {ok: false, raison: 'utilisateur' | 'global'}>}
 */
export async function consommer(kv, uid, { plafondUtilisateur, plafondGlobal, maintenant = Date.now() }) {
  const jour = jourUtc(maintenant);
  const cleG = `g:${jour}`;
  const cleU = `u:${uid}:${jour}`;
  const g = await compter(kv, cleG, plafondGlobal);
  if (!g.ok) return { ok: false, raison: 'global' };
  const u = await compter(kv, cleU, plafondUtilisateur);
  if (!u.ok) return { ok: false, raison: 'utilisateur' };
  const ttl = { expirationTtl: 172_800 };
  await kv.put(cleG, String(g.n + 1), ttl);
  await kv.put(cleU, String(u.n + 1), ttl);
  return { ok: true };
}
