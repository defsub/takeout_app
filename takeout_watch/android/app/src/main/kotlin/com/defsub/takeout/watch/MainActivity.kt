package com.defsub.takeout.watch

import android.os.Bundle
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent.putExtra("background_mode", "transparent")
    }
}

