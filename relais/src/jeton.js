// Vérification d'un jeton d'identité Firebase (JWT RS256) avec WebCrypto,
// sans dépendance. Les clés publiques viennent de Google.

export const URL_CLES =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

export class JetonInvalide extends Error {}

function base64urlVersOctets(texte) {
  const b64 = texte.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, '='));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

function lireJson(partie) {
  try {
    return JSON.parse(new TextDecoder().decode(base64urlVersOctets(partie)));
  } catch {
    throw new JetonInvalide('jeton illisible');
  }
}

/**
 * Renvoie l'uid de l'utilisateur ou lève JetonInvalide.
 * @param {string} jeton
 * @param {{projectId: string, cles: () => Promise<{keys: object[]}>, maintenant?: number}} options
 */
export async function verifierJeton(jeton, { projectId, cles, maintenant = Date.now() }) {
  const parties = (jeton ?? '').split('.');
  if (parties.length !== 3) throw new JetonInvalide('format');
  const entete = lireJson(parties[0]);
  const charge = lireJson(parties[1]);
  if (entete.alg !== 'RS256' || !entete.kid) throw new JetonInvalide('algorithme');

  const jwk = (await cles()).keys.find((k) => k.kid === entete.kid);
  if (!jwk) throw new JetonInvalide('clé inconnue');
  const cle = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valide = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cle,
    base64urlVersOctets(parties[2]),
    new TextEncoder().encode(`${parties[0]}.${parties[1]}`),
  );
  if (!valide) throw new JetonInvalide('signature');

  const s = Math.floor(maintenant / 1000);
  if (charge.iss !== `https://securetoken.google.com/${projectId}`) throw new JetonInvalide('émetteur');
  if (charge.aud !== projectId) throw new JetonInvalide('audience');
  if (typeof charge.exp !== 'number' || charge.exp <= s) throw new JetonInvalide('expiré');
  if (typeof charge.iat !== 'number' || charge.iat > s + 300) throw new JetonInvalide('émis dans le futur');
  if (typeof charge.sub !== 'string' || charge.sub === '') throw new JetonInvalide('sujet');
  return charge.sub;
}

let cache = { at: 0, valeur: null };

/** Clés publiques de Google, gardées une heure. */
export async function clesGoogle(fetcher = fetch) {
  if (cache.valeur && Date.now() - cache.at < 3_600_000) return cache.valeur;
  const r = await fetcher(URL_CLES);
  if (!r.ok) throw new Error('clés indisponibles');
  cache = { at: Date.now(), valeur: await r.json() };
  return cache.valeur;
}
