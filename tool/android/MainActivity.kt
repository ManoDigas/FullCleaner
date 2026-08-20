package com.manodigas.full_cleaner

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "full_cleaner/android"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listApps" -> result.success(listInstalledApps())
                    "openSettings" -> {
                        val targetPackage = call.argument<String>("packageName")
                        if (targetPackage.isNullOrBlank()) {
                            result.error("invalid_package", "Package name is required", null)
                        } else {
                            result.success(openAppSettings(targetPackage))
                        }
                    }
                    "uninstall" -> {
                        val targetPackage = call.argument<String>("packageName")
                        if (targetPackage.isNullOrBlank()) {
                            result.error("invalid_package", "Package name is required", null)
                        } else {
                            result.success(startUninstall(targetPackage))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun listInstalledApps(): List<Map<String, Any?>> {
        val apps = packageManager.getInstalledApplications(0)
        val result = mutableListOf<Map<String, Any?>>()

        for (app in apps) {
            val isSystem = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isLaunchable = packageManager.getLaunchIntentForPackage(app.packageName) != null
            if (isSystem || !isLaunchable || app.packageName == packageName) continue

            val packageInfo = try {
                packageManager.getPackageInfo(app.packageName, 0)
            } catch (_: Exception) {
                null
            }

            result.add(
                mapOf(
                    "name" to packageManager.getApplicationLabel(app).toString(),
                    "packageName" to app.packageName,
                    "versionName" to (packageInfo?.versionName ?: ""),
                )
            )
        }

        return result
    }

    private fun openAppSettings(targetPackage: String): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$targetPackage")
            )
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun startUninstall(targetPackage: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
                data = Uri.parse("package:$targetPackage")
                putExtra(Intent.EXTRA_RETURN_RESULT, false)
            }

            if (intent.resolveActivity(packageManager) == null) {
                return false
            }

            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
