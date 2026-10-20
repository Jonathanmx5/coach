package io.github.jonathanmx5.coach

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast

/** Ouvre la politique de confidentialité (demandée par Health Connect). */
class PolitiqueActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(URL_POLITIQUE)))
        } catch (e: ActivityNotFoundException) {
            // Aucun navigateur (désactivé, profil restreint) : on donne
            // l'adresse plutôt que de planter.
            Toast.makeText(this, URL_POLITIQUE, Toast.LENGTH_LONG).show()
        }
        finish()
    }

    private companion object {
        const val URL_POLITIQUE =
            "https://github.com/Jonathanmx5/coach/blob/main/CONFIDENTIALITE.md"
    }
}
