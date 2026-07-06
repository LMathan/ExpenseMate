package com.example.espenseai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            // Read values from shared widgetData
            val thisMonthSpend = widgetData.getString("thisMonthSpend", "₹0") ?: "₹0"
            val youGet = widgetData.getString("youGet", "₹0") ?: "₹0"
            val youOwe = widgetData.getString("youOwe", "₹0") ?: "₹0"
            val budgetLeft = widgetData.getString("budgetLeft", "₹0") ?: "₹0"
            val hasBudget = widgetData.getBoolean("hasBudget", false)

            // Update Views
            views.setTextViewText(R.id.text_month_spend, thisMonthSpend)
            views.setTextViewText(R.id.text_you_get, "Get $youGet")
            views.setTextViewText(R.id.text_you_owe, "Owe $youOwe")

            if (hasBudget) {
                views.setTextViewText(R.id.text_budget_left, "Left: $budgetLeft")
                views.setViewVisibility(R.id.text_budget_left, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.text_budget_left, View.GONE)
            }

            // Click Intent to open app
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("expensemate://dashboard")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(context.packageName)
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 100, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
