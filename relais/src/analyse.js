export const CONSIGNE = `Tu es un diététicien. Regarde la photo du repas et liste chaque aliment visible avec une estimation de sa quantité et de ses apports.
Réponds UNIQUEMENT avec du JSON, sans texte autour, sous cette forme :
{"aliments":[{"nom":"riz blanc cuit","grammes":150,"kcal":195,"proteines":4,"glucides":42,"lipides":0.5}]}
Les noms sont en français. Si la photo ne montre pas de nourriture, réponds {"aliments":[]}.`;

const borne = (v, min, max) => Math.min(max, Math.max(min, v));
const nombre = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : Number.parseFloat(v));

/** Extrait le premier objet JSON d'une réponse de modèle (avec ou sans ```). */
export function extraireJson(texte) {
  if (typeof texte !== 'string') return null;
  const debut = texte.indexOf('{');
  const fin = texte.lastIndexOf('}');
  if (debut < 0 || fin <= debut) return null;
  try {
    return JSON.parse(texte.slice(debut, fin + 1));
  } catch {
    return null;
  }
}

/**
 * Nettoie la réponse du modèle : au plus 8 aliments, valeurs bornées,
 * calories recalculées depuis les macros si elles manquent.
 * @returns {{nom: string, grammes: number, kcal: number, proteines: number, glucides: number, lipides: number}[] | null}
 */
export function aliments(texteOuObjet) {
  const json = typeof texteOuObjet === 'string' ? extraireJson(texteOuObjet) : texteOuObjet;
  if (!json || !Array.isArray(json.aliments)) return null;
  const sortie = [];
  for (const a of json.aliments) {
    if (!a || typeof a.nom !== 'string' || a.nom.trim() === '') continue;
    const p = borne(nombre(a.proteines) || 0, 0, 500);
    const g = borne(nombre(a.glucides) || 0, 0, 1000);
    const l = borne(nombre(a.lipides) || 0, 0, 500);
    let kcal = nombre(a.kcal);
    if (!Number.isFinite(kcal) || kcal <= 0) kcal = p * 4 + g * 4 + l * 9;
    sortie.push({
      nom: a.nom.trim().slice(0, 60),
      grammes: borne(Math.round(nombre(a.grammes) || 100), 1, 2000),
      kcal: Math.round(borne(kcal, 0, 3000)),
      proteines: Math.round(p * 10) / 10,
      glucides: Math.round(g * 10) / 10,
      lipides: Math.round(l * 10) / 10,
    });
    if (sortie.length === 8) break;
  }
  return sortie;
}

export function versBase64(octets) {
  let bin = '';
  for (let i = 0; i < octets.length; i += 0x8000) {
    bin += String.fromCharCode(...octets.subarray(i, i + 0x8000));
  }
  return btoa(bin);
}

/** Entrée du modèle de vision de Workers AI (messages + image en data URI). */
export function entreeModele(octets) {
  return {
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: CONSIGNE },
          { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${versBase64(octets)}` } },
        ],
      },
    ],
    max_tokens: 700,
    temperature: 0.2,
  };
}
