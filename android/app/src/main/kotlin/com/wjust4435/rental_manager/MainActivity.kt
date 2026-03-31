package com.wjust4435.rental_manager

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.wjust4435.rental_manager/icon"

    // Must match your activity-alias android:name values in AndroidManifest.xml
    private val allAliases = listOf("icon1", "icon2", "icon3")
    private val defaultAlias = "com.wjust4435.rental_manager.MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val iconKey = call.argument<String>("iconKey")
                        try {
                            setAppIcon(iconKey)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ICON_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setAppIcon(iconKey: String?) {
        val pm = packageManager

        if (iconKey == null || iconKey == "default") {
            // Enable default MainActivity, disable all aliases
            pm.setComponentEnabledSetting(
                ComponentName(this, defaultAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            allAliases.forEach { alias ->
                pm.setComponentEnabledSetting(
                    ComponentName(this, "com.wjust4435.rental_manager.$alias"),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } else {
            // Enable selected alias, disable default + all other aliases
            pm.setComponentEnabledSetting(
                ComponentName(this, defaultAlias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            allAliases.forEach { alias ->
                val state = if (alias == iconKey)
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED

                pm.setComponentEnabledSetting(
                    ComponentName(this, "com.wjust4435.rental_manager.$alias"),
                    state,
                    PackageManager.DONT_KILL_APP
                )
            }
        }
    }
}