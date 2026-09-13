package app.pinevault.client

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val manager = getSystemService(AutofillManager::class.java)
            when (call.method) {
                "isEnabled" -> result.success(manager?.hasEnabledAutofillServices() == true)
                "isBackgroundAllowed" -> {
                    val powerManager = getSystemService(PowerManager::class.java)
                    result.success(
                        powerManager?.isIgnoringBatteryOptimizations(packageName) == true,
                    )
                }
                "requestBackgroundAccess" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                    result.success(true)
                }
                "enable" -> {
                    startActivity(
                        Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                            data = Uri.parse("package:$packageName")
                        },
                    )
                    result.success(true)
                }
                "disable" -> {
                    manager?.disableAutofillServices()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val SETTINGS_CHANNEL = "app.pinevault.client/autofill_settings"
    }
}
