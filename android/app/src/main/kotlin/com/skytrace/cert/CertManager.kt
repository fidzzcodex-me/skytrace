package com.skytrace.cert

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.security.KeyChain
import com.skytrace.util.Logger
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyPair
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.Base64
import java.util.concurrent.ConcurrentHashMap
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext

class CertManager(context: Context) {
    private val appContext = context.applicationContext
    private val generator = CertGenerator()
    private val caDir = File(appContext.filesDir, "ca").apply { mkdirs() }
    private val keystoreFile = File(caDir, "ca.p12")
    private val storePassword = "skytrace-local-ca".toCharArray()
    private val lock = Any()

    @Volatile
    private var caKeyPair: KeyPair? = null

    @Volatile
    private var caCert: X509Certificate? = null

    @Volatile
    private var leafKeys: KeyPair? = null

    private val contextCache = object : LinkedHashMap<String, SSLContext>(128, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, SSLContext>?): Boolean = size > 256
    }

    fun hasCa(): Boolean = keystoreFile.exists()

    fun ensureCa() {
        if (caCert != null && caKeyPair != null) return
        synchronized(lock) {
            if (caCert != null && caKeyPair != null) return
            if (keystoreFile.exists()) {
                loadCa()
            } else {
                createCa()
            }
        }
    }

    fun regenerateCa() {
        synchronized(lock) {
            keystoreFile.delete()
            caCert = null
            caKeyPair = null
            synchronized(contextCache) { contextCache.clear() }
            createCa()
        }
    }

    fun caCertificate(): X509Certificate {
        ensureCa()
        return caCert!!
    }

    fun caPem(): String {
        val der = caCertificate().encoded
        val body = Base64.getMimeEncoder(64, "\n".toByteArray()).encodeToString(der)
        return "-----BEGIN CERTIFICATE-----\n$body\n-----END CERTIFICATE-----\n"
    }

    fun fingerprintSha256(): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(caCertificate().encoded)
        return digest.joinToString(":") { String.format("%02X", it) }
    }

    fun status(): Map<String, Any> {
        val generated = hasCa()
        if (!generated) {
            return mapOf("generated" to false, "installed" to false)
        }
        val cert = caCertificate()
        return mapOf(
            "generated" to true,
            "installed" to isInstalled(),
            "fingerprint" to fingerprintSha256(),
            "subject" to cert.subjectX500Principal.name,
            "notAfter" to cert.notAfter.time
        )
    }

    fun isInstalled(): Boolean {
        return try {
            val target = caCertificate().encoded
            val store = KeyStore.getInstance("AndroidCAStore")
            store.load(null, null)
            val aliases = store.aliases()
            while (aliases.hasMoreElements()) {
                val alias = aliases.nextElement()
                if (!alias.startsWith("user:")) continue
                val cert = store.getCertificate(alias) ?: continue
                if (cert.encoded.contentEquals(target)) return true
            }
            false
        } catch (e: Exception) {
            Logger.w("CA store check failed", e)
            false
        }
    }

    fun exportToCache(): File {
        val dir = File(appContext.cacheDir, "certs").apply { mkdirs() }
        val file = File(dir, "skytrace-ca.crt")
        file.writeText(caPem())
        return file
    }

    fun exportToDownloads(): String {
        val pem = caPem().toByteArray()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = appContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, "skytrace-ca.crt")
                put(MediaStore.Downloads.MIME_TYPE, "application/x-x509-ca-cert")
                put(MediaStore.Downloads.RELATIVE_PATH, "Download")
            }
            val existing = resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Downloads._ID),
                "${MediaStore.Downloads.DISPLAY_NAME} = ?",
                arrayOf("skytrace-ca.crt"),
                null
            )
            existing?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getLong(0)
                    resolver.delete(
                        android.content.ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id),
                        null,
                        null
                    )
                }
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("cannot create download entry")
            resolver.openOutputStream(uri)?.use { it.write(pem) }
            return "Download/skytrace-ca.crt"
        }
        val file = exportToCache()
        return file.absolutePath
    }

    fun installIntent(): Intent {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            KeyChain.createInstallIntent().apply {
                putExtra(KeyChain.EXTRA_CERTIFICATE, caCertificate().encoded)
                putExtra(KeyChain.EXTRA_NAME, "SkyTrace Local CA")
            }
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
    }

    fun contextFor(host: String): SSLContext {
        ensureCa()
        synchronized(contextCache) {
            contextCache[host]?.let { return it }
        }
        val keys = leafKeys ?: synchronized(lock) {
            leafKeys ?: generator.generateLeafKeyPair().also { leafKeys = it }
        }
        val leaf = generator.generateLeaf(host, keys, caKeyPair!!, caCert!!)
        val ks = KeyStore.getInstance("PKCS12")
        ks.load(null, null)
        ks.setKeyEntry("leaf", keys.private as PrivateKey, storePassword, arrayOf<java.security.cert.Certificate>(leaf, caCert!!))
        val kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
        kmf.init(ks, storePassword)
        val ctx = SSLContext.getInstance("TLS")
        ctx.init(kmf.keyManagers, null, null)
        synchronized(contextCache) { contextCache[host] = ctx }
        return ctx
    }

    private fun createCa() {
        val (pair, cert) = generator.generateCa()
        val ks = KeyStore.getInstance("PKCS12")
        ks.load(null, null)
        ks.setKeyEntry("ca", pair.private, storePassword, arrayOf<java.security.cert.Certificate>(cert))
        FileOutputStream(keystoreFile).use { ks.store(it, storePassword) }
        caKeyPair = pair
        caCert = cert
        Logger.i("CA generated")
    }

    private fun loadCa() {
        val ks = KeyStore.getInstance("PKCS12")
        FileInputStream(keystoreFile).use { ks.load(it, storePassword) }
        val key = ks.getKey("ca", storePassword) as PrivateKey
        val cert = ks.getCertificate("ca") as X509Certificate
        caKeyPair = KeyPair(cert.publicKey, key)
        caCert = cert
    }

    companion object {
        fun parsePem(pem: String): X509Certificate {
            val factory = CertificateFactory.getInstance("X.509")
            return factory.generateCertificate(ByteArrayInputStream(pem.toByteArray())) as X509Certificate
        }
    }
}
