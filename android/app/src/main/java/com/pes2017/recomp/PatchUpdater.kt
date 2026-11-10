package com.pes2017.recomp

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Downloads versioned data patches without replacing the APK.
 *
 * Patch files are deliberately confined to filesDir/patches. Native libraries,
 * DEX/Kotlin code and Android resources remain APK-owned and require a signed APK
 * update. Each patch is hash-checked and atomically replaced; the previous file
 * is retained as .bak until the next successful update.
 */
object PatchUpdater {
    data class Result(val updated: Int, val checked: Int, val message: String)

    fun checkAndApply(context: Context, manifestUrl: String): Result {
        require(manifestUrl.startsWith("https://")) { "Patch manifest must use HTTPS" }
        val manifestText = downloadText(manifestUrl, 1024 * 1024)
        val manifest = JSONObject(manifestText)
        require(manifest.optInt("schema", 0) == 1) { "Unsupported patch manifest schema" }
        val patches = manifest.optJSONArray("patches") ?: return Result(0, 0, "No patches published")
        val root = File(context.filesDir, "patches").canonicalFile
        if (!root.exists() && !root.mkdirs()) throw IllegalStateException("Cannot create patch directory")
        val versions = context.getSharedPreferences("patch_versions", Context.MODE_PRIVATE)
        var updated = 0
        var checked = 0
        val seen = HashSet<String>()

        for (i in 0 until patches.length()) {
            val item = patches.getJSONObject(i)
            val id = item.optString("id")
            val version = item.optInt("version", 0)
            val target = item.optString("target")
            val url = item.optString("url")
            val expectedHash = item.optString("sha256").lowercase()
            require(id.matches(Regex("[A-Za-z0-9._-]{1,80}")) && seen.add(id)) { "Invalid or duplicate patch id" }
            require(version > 0) { "Invalid patch version for $id" }
            require(url.startsWith("https://")) { "Patch URL must use HTTPS" }
            require(expectedHash.matches(Regex("[a-f0-9]{64}"))) { "Invalid SHA-256 for $id" }
            require(target.isNotBlank() && !target.startsWith("/") && !target.contains("\\") &&
                target.split("/").none { it.isBlank() || it == "." || it == ".." }) { "Unsafe patch target" }

            checked++
            if (version <= versions.getInt(id, 0)) continue

            val destination = File(root, target).canonicalFile
            require(destination.path.startsWith(root.path + File.separator)) { "Patch target escapes patch directory" }
            val bytes = downloadBytes(url, 64 * 1024 * 1024)
            val actualHash = MessageDigest.getInstance("SHA-256")
                .digest(bytes).joinToString("") { "%02x".format(it) }
            require(actualHash == expectedHash) { "SHA-256 mismatch for $id" }

            destination.parentFile?.let {
                if (!it.exists() && !it.mkdirs()) throw IllegalStateException("Cannot create patch target directory")
            }
            val temporary = File(destination.parentFile, destination.name + ".download")
            val backup = File(destination.parentFile, destination.name + ".bak")
            temporary.writeBytes(bytes)
            if (destination.exists()) {
                if (backup.exists() && !backup.delete()) throw IllegalStateException("Cannot replace old patch backup")
                if (!destination.renameTo(backup)) throw IllegalStateException("Cannot back up existing patch")
            }
            if (!temporary.renameTo(destination)) {
                if (backup.exists()) backup.renameTo(destination)
                throw IllegalStateException("Cannot activate downloaded patch")
            }
            versions.edit().putInt(id, version).apply()
            updated++
        }
        return Result(updated, checked, if (updated == 0) "Already up to date" else "Updated $updated file(s)")
    }

    private fun downloadText(address: String, limit: Int): String =
        downloadBytes(address, limit).toString(Charsets.UTF_8)

    private fun downloadBytes(address: String, limit: Int): ByteArray {
        val connection = (URL(address).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 30000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Don-Libarti-Patch-Updater")
        }
        try {
            val code = connection.responseCode
            require(code == HttpURLConnection.HTTP_OK) { "Patch server returned HTTP $code" }
            require(connection.contentLengthLong <= limit || connection.contentLengthLong < 0) {
                "Patch file exceeds size limit"
            }
            return connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    require(total <= limit) { "Patch file exceeds size limit" }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
        } finally {
            connection.disconnect()
        }
    }
}
