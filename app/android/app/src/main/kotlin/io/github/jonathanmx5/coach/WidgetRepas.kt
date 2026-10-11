package io.github.jonathanmx5.coach

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget « repas » : calories et protéines du jour, et un bouton qui ouvre
 * directement l'écran de photo du repas (adresse coach://photo).
 */
class WidgetRepas : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val vues = RemoteViews(context.packageName, R.layout.widget_repas)
            vues.setTextViewText(R.id.repas_texte, widgetData.getString("repas_texte", "—"))
            vues.setTextViewText(R.id.repas_proteines, widgetData.getString("proteines_texte", ""))
            vues.setOnClickPendingIntent(
                R.id.repas_photo,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("coach://photo")),
            )
            vues.setOnClickPendingIntent(
                R.id.repas_racine,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, vues)
        }
    }
}
