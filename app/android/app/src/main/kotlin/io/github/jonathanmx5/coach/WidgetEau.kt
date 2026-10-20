package io.github.jonathanmx5.coach

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Petit widget d'hydratation : eau bue, barre de progression et deux boutons
 * pour en ajouter sans ouvrir l'application (mêmes adresses coach://eau que le
 * grand widget). Un autre jour que celui du total enregistré, il affiche 0 ;
 * sans compte connecté, il invite à se connecter.
 */
class WidgetEau : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val objectif = DonneesWidget.objectifEau(widgetData)
        val ml = DonneesWidget.eauDuJour(widgetData)
        val texte =
            if (DonneesWidget.connecte(widgetData)) {
                DonneesWidget.eauTexte(widgetData)
            } else {
                context.getString(R.string.widget_connecte_toi)
            }
        for (id in appWidgetIds) {
            val vues = RemoteViews(context.packageName, R.layout.widget_eau)
            vues.setTextViewText(R.id.eau_texte, texte)
            vues.setProgressBar(R.id.eau_barre, objectif, ml, false)
            vues.setOnClickPendingIntent(
                R.id.eau_plus250,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("coach://eau?ml=250")),
            )
            vues.setOnClickPendingIntent(
                R.id.eau_plus500,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("coach://eau?ml=500")),
            )
            vues.setOnClickPendingIntent(
                R.id.eau_racine,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, vues)
        }
    }
}
