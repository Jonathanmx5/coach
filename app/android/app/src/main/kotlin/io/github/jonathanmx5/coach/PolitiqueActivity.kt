package io.github.jonathanmx5.coach

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/** Ouvre la politique de confidentialité (demandée par Health Connect). */
class PolitiqueActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(URL_POLITIQUE)))
        finish()
    }

    private companion object {
        const val URL_POLITIQUE =
            "https://github.com/Jonathanmx5/coach/blob/main/CONFIDENTIALITE.md"
    }
}
