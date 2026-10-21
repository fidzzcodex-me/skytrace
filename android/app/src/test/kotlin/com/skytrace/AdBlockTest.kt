package com.skytrace

import com.skytrace.adblock.AdBlock
import com.skytrace.vpn.DnsCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AdBlockTest {
    @Test
    fun suffixMatchCoversSubdomainsOnly() {
        val set = setOf("doubleclick.net", "ads.example.com")
        assertTrue(AdBlock.suffixMatch(set, "doubleclick.net"))
        assertTrue(AdBlock.suffixMatch(set, "stats.g.doubleclick.net"))
        assertTrue(AdBlock.suffixMatch(set, "x.ads.example.com"))
        assertFalse(AdBlock.suffixMatch(set, "example.com"))
        assertFalse(AdBlock.suffixMatch(set, "notdoubleclick.net"))
        assertFalse(AdBlock.suffixMatch(emptySet(), "anything.com"))
    }

    @Test
    fun entriesSplitIntoDomainsAndPatterns() {
        val (domains, patterns) = AdBlock.parseEntries("Ads.Example.com\n*.tracker.io, .cdn.test ; # note\n")
        assertTrue(domains.contains("ads.example.com"))
        assertTrue(domains.contains("cdn.test"))
        assertEquals(1, patterns.size)
        assertTrue(patterns[0].containsMatchIn("a.tracker.io"))
        assertFalse(patterns[0].containsMatchIn("tracker.io.evil.com.x"))
    }

    private val query = byteArrayOf(
        0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0,
        3, 'a'.code.toByte(), 'd'.code.toByte(), 's'.code.toByte(),
        7, 'e'.code.toByte(), 'x'.code.toByte(), 'a'.code.toByte(), 'm'.code.toByte(), 'p'.code.toByte(), 'l'.code.toByte(), 'e'.code.toByte(),
        3, 'c'.code.toByte(), 'o'.code.toByte(), 'm'.code.toByte(), 0,
        0, 1, 0, 1
    )

    @Test
    fun dnsQuestionNameIsExtracted() {
        assertEquals("ads.example.com", DnsCache.questionName(query))
        assertNull(DnsCache.questionName(ByteArray(4)))
    }

    @Test
    fun nxdomainReplyKeepsQuestionAndSetsRcode() {
        val reply = DnsCache.nxdomainResponse(query)
        assertEquals(query.size, reply.size)
        assertEquals(0x81, reply[2].toInt() and 0xFF)
        assertEquals(0x83, reply[3].toInt() and 0xFF)
        assertEquals(1, reply[5].toInt())
        assertEquals(0, reply[7].toInt())
    }
}
