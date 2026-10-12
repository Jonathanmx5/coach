package io.github.jonathanmx5.coach

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Widget de l'écran d'accueil : anneaux du jour, eau bue et deux boutons pour
 * ajouter de l'eau sans ouvrir l'application, et un bouton appareil photo. Les données viennent de l'appli
 * (clés « anneaux », « eau_texte », « bilan_texte ») ; les boutons appellent du
 * code Dart en arrière-plan (adresses coach://eau?ml=250 et ml=500).
 */
class WidgetCoach : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val vues = RemoteViews(context.packageName, R.layout.widget_coach)

            val image = widgetData.getString("anneaux", null)
            if (image != null && File(image).exists()) {
                BitmapFactory.decodeFile(image)?.let {
                    vues.setImageViewBitmap(R.id.widget_anneaux, it)
                }
            }
            vues.setTextViewText(R.id.widget_eau, widgetData.getString("eau_texte", "—"))
            vues.setTextViewText(R.id.widget_bilan, widgetData.getString("bilan_texte", ""))

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
