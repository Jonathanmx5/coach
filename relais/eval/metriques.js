// Calculs de l'évaluation, sans réseau (testés dans test/eval.test.js).

/** Écart relatif |estimé − référence| / référence ; null sans référence valable. */
export function ecartRelatif(estime, reference) {
  if (!Number.isFinite(estime) || !Number.isFinite(reference) || reference <= 0) return null;
  return Math.abs(estime - reference) / reference;
}

const mediane = (valeurs) => {
  if (valeurs.length === 0) return null;
  const t = [...valeurs].sort((a, b) => a - b);
  const m = Math.floor(t.length / 2);
  return t.length % 2 ? t[m] : (t[m - 1] + t[m]) / 2;
};

const moyenne = (valeurs) => (valeurs.length === 0 ? null : valeurs.reduce((a, b) => a + b, 0) / valeurs.length);

/**
 * Résume les essais d'un modèle.
 * @param {{ok: boolean, kcalEstime?: number, kcalRef?: number, grammesEstime?: number, grammesRef?: number, dansFourchette?: boolean, ms?: number}[]} essais
 */
export function resumer(essais) {
  const reussis = essais.filter((e) => e.ok);
  const ecartsKcal = reussis.map((e) => ecartRelatif(e.kcalEstime, e.kcalRef)).filter((v) => v !== null);
  const ecartsGrammes = reussis.map((e) => ecartRelatif(e.grammesEstime, e.grammesRef)).filter((v) => v !== null);
  const fourchettes = reussis.filter((e) => typeof e.dansFourchette === 'boolean');
  return {
    photos: essais.length,
    lisibles: reussis.length,
    tauxLisible: essais.length === 0 ? 0 : reussis.length / essais.length,
    ecartKcalMedian: mediane(ecartsKcal),
    ecartKcalMoyen: moyenne(ecartsKcal),
    dans20pc: ecartsKcal.length === 0 ? null : ecartsKcal.filter((v) => v <= 0.2).length / ecartsKcal.length,
    ecartGrammesMedian: mediane(ecartsGrammes),
    fourchetteJuste: fourchettes.length === 0 ? null : fourchettes.filter((e) => e.dansFourchette).length / fourchettes.length,
    dureeMoyenneMs: moyenne(essais.map((e) => e.ms).filter((v) => Number.isFinite(v))),
  };
}

/** Le poids pesé du repas est-il dans la somme des fourchettes des aliments ? */
export function dansLaFourchette(aliments, grammesRef) {
  const min = aliments.reduce((s, a) => s + (a.grammes_min ?? a.grammes), 0);
  const max = aliments.reduce((s, a) => s + (a.grammes_max ?? a.grammes), 0);
  return grammesRef >= min && grammesRef <= max;
}

export const pourcent = (v) => (v === null || v === undefined ? '—' : `${Math.round(v * 100)} %`);
