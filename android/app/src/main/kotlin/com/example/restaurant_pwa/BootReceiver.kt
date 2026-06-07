package com.example.restaurant_pwa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Cuando termina el boot del tablet, abre la app de Gorditas Mesero.
 * Útil para tablets que NO estén configurados con esta app como launcher
 * (CATEGORY_HOME): si el "App de inicio" sigue siendo el launcher de
 * Android, este receiver levanta la app igual.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {
            val launchIntent = Intent(context, MainActivity::class.java)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
        }
    }
}
