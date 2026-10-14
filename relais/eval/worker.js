// Worker d'évaluation : appelle directement les modèles (sans jeton Firebase ni
// plafonds) pour comparer leur qualité. Lancé par comparer.js ; ne pas déployer.
import { analyse, entreeModele } from '../src/analyse.js';
import { appelerGemini } from '../src/gemini.js';

export default {
  async fetch(requete, env) {
    const octets = new Uint8Array(await requete.arrayBuffer());
    const url = new URL(requete.url);
    const modele = url.searchParams.get('m');
    const t0 = Date.now();
    try {
      let texte;
      if (modele === 'gemini') {
        if (!env.GEMINI_API_KEY) return Response.json({ erreur: 'pas de clé Gemini' }, { status: 400 });
        texte = await appelerGemini(octets, '', {
          cle: env.GEMINI_API_KEY,
          modele: env.GEMINI_MODELE ?? 'gemini-3.8-flash',
        });
      } else {
        const brut = await env.AI.run(modele, entreeModele(octets, ''));
        texte = brut?.response ?? brut?.choices?.[0]?.message?.content ?? brut;
      }
      return Response.json({ ms: Date.now() - t0, analyse: analyse(texte) });
    } catch (e) {
      return Response.json({ erreur: String(e) }, { status: 500 });
    }
  },
};
