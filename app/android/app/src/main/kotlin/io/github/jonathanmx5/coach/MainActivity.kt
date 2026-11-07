package io.github.jonathanmx5.coach

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity : exigée par l'extension health pour les autorisations.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Rouverte depuis les applications récentes, l'activité reçoit de
        // nouveau l'intent qui l'avait lancée : celui d'un bouton du widget
        // (« Photographier ») rouvrirait l'appareil photo sans qu'on l'ait
        // demandé. On repart d'un lancement ordinaire.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) {
            intent = Intent(Intent.ACTION_MAIN)
        }
        super.onCreate(savedInstanceState)
    }
}
