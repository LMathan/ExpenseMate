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

class LargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_large)

            // Read values
            val thisMonthSpend = widgetData.getString("thisMonthSpend", "₹0") ?: "₹0"
            val youGet = widgetData.getString("youGet", "₹0") ?: "₹0"
            val youOwe = widgetData.getString("youOwe", "₹0") ?: "₹0"
            val budgetLeft = widgetData.getString("budgetLeft", "₹0") ?: "₹0"
            val budgetLimit = widgetData.getString("budgetLimit", "₹0") ?: "₹0"
            val expensesToday = widgetData.getString("expensesToday", "0") ?: "0"
            val topCategory = widgetData.getString("topCategory", "None") ?: "None"
            val monthName = widgetData.getString("monthName", "This Month") ?: "This Month"
            val hasBudget = widgetData.getBoolean("hasBudget", false)

            // Update Views
            views.setTextViewText(R.id.text_month_spend, thisMonthSpend)
            views.setTextViewText(R.id.text_you_get, "Get $youGet")
            views.setTextViewText(R.id.text_you_owe, "Owe $youOwe")
            views.setTextViewText(R.id.text_expenses_today, "$expensesToday txn")
            views.setTextViewText(R.id.text_top_category, topCategory)
            views.setTextViewText(R.id.text_month_name, monthName)

            if (hasBudget) {
                views.setTextViewText(R.id.text_budget_left, "$budgetLeft left")
                views.setTextViewText(R.id.text_budget_limit, "Limit: $budgetLimit")
                views.setViewVisibility(R.id.budget_section, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.budget_section, View.GONE)
            }

            // 1. General Tap Intent (Root Click -> Open Dashboard)
            val rootIntent = Intent(Intent.ACTION_VIEW, Uri.parse("expensemate://dashboard")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(context.packageName)
            }
            val rootPendingIntent = PendingIntent.getActivity(
                context, 300, rootIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)

            // 2. Quick Action Intent: Add Expense
            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("expensemate://add_expense")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(context.packageName)
            }
            val addPendingIntent = PendingIntent.getActivity(
                context, 301, addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_add_expense, addPendingIntent)

            // 3. Quick Action Intent: Splits
            val splitsIntent = Intent(Intent.ACTION_VIEW, Uri.parse("expensemate://splits")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(context.packageName)
            }
            val splitsPendingIntent = PendingIntent.getActivity(
                context, 302, splitsIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_splits, splitsPendingIntent)

            // 4. Quick Action Intent: Dashboard
            val dashboardIntent = Intent(Intent.ACTION_VIEW, Uri.parse("expensemate://dashboard")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                setPackage(context.packageName)
            }
            val dashboardPendingIntent = PendingIntent.getActivity(
                context, 303, dashboardIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_dashboard, dashboardPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
