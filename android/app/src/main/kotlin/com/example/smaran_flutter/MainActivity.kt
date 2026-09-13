package com.example.smaran_flutter

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenFlags(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockScreenFlags(intent)
    }

    private fun applyLockScreenFlags(intent: Intent?) {
        // Detect if we were launched by the alarm notification
        val isAlarmLaunch = intent?.getBooleanExtra("smaran_alarm_launch", false) ?: false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(isAlarmLaunch)
            setTurnScreenOn(isAlarmLaunch)
        }

        if (isAlarmLaunch) {
            // Wake screen even when locked
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
                )
            }
        }
    }
}