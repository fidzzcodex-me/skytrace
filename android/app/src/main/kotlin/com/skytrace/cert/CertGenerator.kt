package com.skytrace.cert

import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.ExtendedKeyUsage
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.asn1.x509.GeneralName
import org.bouncycastle.asn1.x509.GeneralNames
import org.bouncycastle.asn1.x509.KeyPurposeId
import org.bouncycastle.asn1.x509.KeyUsage
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509CertificateHolder
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.util.Date
import java.util.concurrent.TimeUnit

class CertGenerator {
    private val provider = BouncyCastleProvider()
    private val random = SecureRandom()
    private val extUtils = JcaX509ExtensionUtils()

    fun generateCa(commonName: String = "SkyTrace Local CA"): Pair<KeyPair, X509Certificate> {
        val generator = KeyPairGenerator.getInstance("RSA")
        generator.initialize(2048, random)
        val keyPair = generator.generateKeyPair()
        val subject = X500Name("CN=$commonName, O=SkyTrace, OU=Local Debugging")
        val now = System.currentTimeMillis()
        val builder: X509v3CertificateBuilder = JcaX509v3CertificateBuilder(
            subject,
            serial(),
            Date(now - TimeUnit.DAYS.toMillis(1)),
            Date(now + TimeUnit.DAYS.toMillis(3650)),
            subject,
            keyPair.public
        )
        builder.addExtension(Extension.basicConstraints, true, BasicConstraints(true))
        builder.addExtension(Extension.keyUsage, true, KeyUsage(KeyUsage.keyCertSign or KeyUsage.cRLSign or KeyUsage.digitalSignature))
        builder.addExtension(Extension.subjectKeyIdentifier, false, extUtils.createSubjectKeyIdentifier(keyPair.public))
        val signer = JcaContentSignerBuilder("SHA256withRSA").setProvider(provider).build(keyPair.private)
        val cert = JcaX509CertificateConverter().setProvider(provider).getCertificate(builder.build(signer))
        return Pair(keyPair, cert)
    }

    fun generateLeafKeyPair(): KeyPair {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"), random)
        return generator.generateKeyPair()
    }

    fun generateLeaf(
        host: String,
        leafKeys: KeyPair,
        caKey: KeyPair,
        caCert: X509Certificate
    ): X509Certificate {
        val subject = X500Name("CN=${sanitizeCn(host)}, O=SkyTrace")
        val issuer = JcaX509CertificateHolder(caCert).subject
        val now = System.currentTimeMillis()
        val builder = JcaX509v3CertificateBuilder(
            issuer,
            serial(),
            Date(now - TimeUnit.DAYS.toMillis(1)),
            Date(now + TimeUnit.DAYS.toMillis(365)),
            subject,
            leafKeys.public
        )
        builder.addExtension(Extension.basicConstraints, true, BasicConstraints(false))
        builder.addExtension(Extension.keyUsage, true, KeyUsage(KeyUsage.digitalSignature or KeyUsage.keyEncipherment))
        builder.addExtension(Extension.extendedKeyUsage, false, ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth))
        builder.addExtension(Extension.subjectKeyIdentifier, false, extUtils.createSubjectKeyIdentifier(leafKeys.public))
        builder.addExtension(Extension.authorityKeyIdentifier, false, extUtils.createAuthorityKeyIdentifier(caCert))
        val type = if (isIpAddress(host)) GeneralName.iPAddress else GeneralName.dNSName
        builder.addExtension(Extension.subjectAlternativeName, false, GeneralNames(GeneralName(type, host)))
        val signer = JcaContentSignerBuilder("SHA256withRSA").setProvider(provider).build(caKey.private)
        return JcaX509CertificateConverter().setProvider(provider).getCertificate(builder.build(signer))
    }

    private fun serial(): BigInteger = BigInteger(64, random).abs().add(BigInteger.ONE)

    private fun sanitizeCn(host: String): String = host.replace(Regex("[,=+<>#;\"\\\\]"), "_").take(64)

    private fun isIpAddress(host: String): Boolean =
        Regex("^\\d{1,3}(\\.\\d{1,3}){3}$").matches(host) || host.contains(':')
}
