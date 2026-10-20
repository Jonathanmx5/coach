package io.github.jonathanmx5.coach

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Widget de l'écran d'accueil : anneaux du jour au centre (calories brûlées,
 * mangées, protéines), eau bue en barre, quatre boutons pour ajouter de l'eau
 * sans ouvrir l'application et un bouton appareil photo. Les données viennent
 * de l'appli (clés « anneaux », « anneaux_description », « eau_texte »,
 * « eau_ml », « bilan_texte »...) ; les boutons d'eau appellent du code Dart en
 * arrière-plan (adresses coach://eau?ml=...). Les chiffres d'un autre jour ne
 * sont pas montrés (anneaux masqués, « — ») ; sans compte connecté, le widget
 * invite à se connecter.
 */
class WidgetCoach : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val connecte = DonneesWidget.connecte(widgetData)
        val duJour = connecte && DonneesWidget.duJour(widgetData, "donnees_jour")
        val anneaux =
            if (duJour) {
                widgetData.getString("anneaux", null)
                    ?.takeIf { File(it).exists() }
                    ?.let { BitmapFactory.decodeFile(it) }
            } else {
                null
            }
        val bilan =
            when {
                !connecte -> context.getString(R.string.widget_connecte_toi)
                duJour -> widgetData.getString("bilan_texte", null) ?: ""
                else -> DonneesWidget.VIDE
            }
        // Les chiffres des anneaux pour le lecteur d'écran (ils ne sont que
        // dans l'image).
        val description =
            widgetData.getString("anneaux_description", null)?.takeIf { it.isNotEmpty() }
                ?: context.getString(R.string.widget_anneaux_description)

        for (id in appWidgetIds) {
            val vues = RemoteViews(context.packageName, R.layout.widget_coach)

            if (anneaux != null) {
                vues.setImageViewBitmap(R.id.widget_anneaux, anneaux)
                vues.setContentDescription(R.id.widget_anneaux, description)
                vues.setViewVisibility(R.id.widget_anneaux, View.VISIBLE)
            } else {
                vues.setViewVisibility(R.id.widget_anneaux, View.GONE)
            }
            vues.setTextViewText(
                R.id.widget_eau,
                if (connecte) DonneesWidget.eauTexte(widgetData) else DonneesWidget.VIDE,
            )
            vues.setProgressBar(
                R.id.widget_eau_barre,
                DonneesWidget.objectifEau(widgetData),
                DonneesWidget.eauDuJour(widgetData),
                false,
            )
            vues.setTextViewText(R.id.widget_bilan, bilan)

            for ((bouton, ml) in listOf(
                R.id.widget_plus1000 to 1000,
                R.id.widget_plus500 to 500,
                R.id.widget_plus250 to 250,
                R.id.widget_plus180 to 180,
            )) {
                vues.setOnClickPendingIntent(
                    bouton,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("coach://eau?ml=$ml")),
                )
            }
            vues.setOnClickPendingIntent(
                R.id.widget_photo,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("coach://photo?source=appareil"),
                ),
            )
            val ouvrir = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            vues.setOnClickPendingIntent(R.id.widget_racine, ouvrir)
            vues.setOnClickPendingIntent(R.id.widget_anneaux, ouvrir)

            appWidgetManager.updateAppWidget(id, vues)
        }
    }
}
