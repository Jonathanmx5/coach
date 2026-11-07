package io.github.jonathanmx5.coach

import android.content.SharedPreferences
import java.time.LocalDate

/**
 * Lecture commune des données que l'appli enregistre pour les widgets (voir
 * lib/widget/donnees_widget.dart). Les chiffres sont datés : le lendemain,
 * avant que l'appli ne les remplace, les widgets ne montrent pas ceux de la
 * veille.
 */
internal object DonneesWidget {
    /** Texte affiché à la place d'un chiffre qui n'est pas celui du jour. */
    const val VIDE = "—"

    /**
     * Vrai si la clé [cle] (« donnees_jour » pour les chiffres du jour,
     * « eau_jour » pour l'eau) vaut la date du jour, au format AAAA-MM-JJ de
     * l'appli.
     */
    fun duJour(prefs: SharedPreferences, cle: String): Boolean =
        prefs.getString(cle, null) == LocalDate.now().toString()

    /**
     * Faux quand l'appli a tout effacé (déconnexion, compte supprimé) ou n'a
     * encore rien envoyé : le widget invite alors à se connecter.
     */
    fun connecte(prefs: SharedPreferences): Boolean =
        prefs.getString("uid", null) != null || prefs.getString("eau_texte", null) != null

    /** Objectif d'eau du jour en ml (2 L par défaut, comme l'appli). */
    fun objectifEau(prefs: SharedPreferences): Int =
        (prefs.getString("eau_objectif_ml", null)?.toIntOrNull() ?: 2000).coerceAtLeast(1)

    /** Eau bue aujourd'hui en ml, 0 si le total enregistré date d'un autre jour. */
    fun eauDuJour(prefs: SharedPreferences): Int =
        if (duJour(prefs, "eau_jour")) {
            (prefs.getString("eau_ml", null)?.toIntOrNull() ?: 0).coerceIn(0, objectifEau(prefs))
        } else {
            0
        }

    /** « 1,25 / 2,65 L » s'il est du jour, sinon « — ». */
    fun eauTexte(prefs: SharedPreferences): String =
        if (duJour(prefs, "eau_jour")) prefs.getString("eau_texte", null) ?: VIDE else VIDE
}
