package huynang.stridequest

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect asks for permissions through a fragment activity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Open settings" on the health gate: Health Connect's own settings, or the
        // settings page of this app when Health Connect has none.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stridequest/settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val healthConnect = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
                val app = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                )
                try {
                    startActivity(healthConnect)
                } catch (error: Exception) {
                    startActivity(app)
                }
                result.success(null)
            }
    }
}
