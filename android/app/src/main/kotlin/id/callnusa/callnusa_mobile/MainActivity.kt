package id.callnusa.callnusa_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The Core outlives any single Activity instance, so it is anchored to
        // the application context rather than to this Activity.
        val plugin = LinphonePlugin(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LinphonePlugin.METHOD_CHANNEL)
            .setMethodCallHandler(plugin)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LinphonePlugin.EVENT_CHANNEL)
            .setStreamHandler(plugin)
    }
}
