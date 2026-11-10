package com.pes2017.recomp

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * Optional remote graphics values delivered by the data-only patch channel.
 * Only keys explicitly present in "managed" override the player's local
 * preferences; an empty object leaves every local setting untouched.
 */
class PatchSettings(context: Context) {
    private val managed: JSONObject = try {
        val file = File(context.filesDir, "patches/graphics.json")
        if (file.isFile) JSONObject(file.readText()).optJSONObject("managed") ?: JSONObject()
        else JSONObject()
    } catch (_: Throwable) {
        JSONObject()
    }

    fun int(key: String, fallback: Int): Int =
        if (managed.has(key)) managed.optInt(key, fallback) else fallback

    fun float(key: String, fallback: Float): Float =
        if (managed.has(key)) managed.optDouble(key, fallback.toDouble()).toFloat() else fallback

    fun bool(key: String, fallback: Boolean): Boolean =
        if (managed.has(key)) managed.optBoolean(key, fallback) else fallback
}
