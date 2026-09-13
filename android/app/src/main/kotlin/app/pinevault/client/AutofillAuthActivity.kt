package app.pinevault.client

import android.content.Intent
import android.os.Build
import android.service.autofill.Dataset
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AutofillAuthActivity : FlutterFragmentActivity() {
    override fun getDartEntrypointFunctionName(): String = "autofillEntryPoint"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AutofillContract.AUTH_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> result.success(
                    mapOf(
                        "packageNames" to intent.getStringArrayListExtra(
                            AutofillContract.EXTRA_PACKAGE_NAMES,
                        ).orEmpty(),
                        "webDomains" to intent.getStringArrayListExtra(
                            AutofillContract.EXTRA_WEB_DOMAINS,
                        ).orEmpty(),
                    ),
                )
                "complete" -> complete(call, result)
                "cancel" -> {
                    setResult(RESULT_CANCELED)
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun complete(call: MethodCall, result: MethodChannel.Result) {
        val username = call.argument<String>("username").orEmpty()
        val password = call.argument<String>("password").orEmpty()
        val label = call.argument<String>("label").orEmpty().ifBlank { "松匣" }
        val usernameIds = parcelableIds(AutofillContract.EXTRA_USERNAME_IDS)
        val passwordIds = parcelableIds(AutofillContract.EXTRA_PASSWORD_IDS)
        if (password.isEmpty() || passwordIds.isEmpty()) {
            result.error("invalid_result", "没有可填充的密码字段", null)
            return
        }
        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, label)
        }
        val dataset = Dataset.Builder(presentation).apply {
            if (username.isNotEmpty()) {
                usernameIds.forEach { id ->
                    setValue(id, AutofillValue.forText(username), presentation)
                }
            }
            passwordIds.forEach { id ->
                setValue(id, AutofillValue.forText(password), presentation)
            }
            setId("pinevault_selected")
        }.build()
        val reply = Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT_EPHEMERAL_DATASET, true)
            }
        }
        setResult(RESULT_OK, reply)
        finish()
        result.success(true)
    }

    @Suppress("DEPRECATION")
    private fun parcelableIds(name: String): ArrayList<AutofillId> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(name, AutofillId::class.java) ?: arrayListOf()
        } else {
            intent.getParcelableArrayListExtra(name) ?: arrayListOf()
        }
}
