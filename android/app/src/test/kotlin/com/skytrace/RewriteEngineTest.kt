package com.skytrace

import com.skytrace.proxy.Header
import com.skytrace.proxy.HttpRequestMsg
import com.skytrace.rule.Rule
import com.skytrace.rule.RuleAction
import com.skytrace.rule.RulePhase
import com.skytrace.rule.RewriteEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RewriteEngineTest {
    private fun request(): HttpRequestMsg = HttpRequestMsg(
        method = "GET",
        target = "/v1/users?id=7",
        version = "HTTP/1.1",
        headers = mutableListOf(Header("Host", "api.example.com"), Header("Accept", "application/json")),
        body = ByteArray(0),
        scheme = "https",
        host = "api.example.com",
        port = 443
    )

    @Test
    fun globMatchesUrlAndHostPath() {
        val engine = RewriteEngine()
        assertTrue(engine.urlMatches("*example.com/v1/*", false, "https://api.example.com/v1/users"))
        assertTrue(engine.urlMatches("api.example.com/v1/*", false, "https://api.example.com/v1/users"))
        assertFalse(engine.urlMatches("*other.com*", false, "https://api.example.com/v1/users"))
        assertTrue(engine.urlMatches("^https://api\\..*/users", true, "https://api.example.com/users"))
    }

    @Test
    fun setsRequestHeader() {
        val engine = RewriteEngine()
        engine.load(
            listOf(
                Rule(
                    id = 1,
                    urlPattern = "*example.com*",
                    action = RuleAction.MODIFY_HEADER,
                    phase = RulePhase.REQUEST,
                    headerOp = "set",
                    headerName = "X-Debug",
                    headerValue = "1"
                )
            )
        )
        val req = request()
        val outcome = engine.applyRequest(req, "com.test")
        assertTrue(outcome.modified)
        assertEquals("1", req.headers.first { it.name == "X-Debug" }.value)
    }

    @Test
    fun mockShortCircuitsRequest() {
        val engine = RewriteEngine()
        engine.load(
            listOf(
                Rule(
                    id = 2,
                    urlPattern = "*/v1/users*",
                    action = RuleAction.MOCK,
                    mockStatus = 418,
                    mockBody = "{\"ok\":true}"
                )
            )
        )
        val outcome = engine.applyRequest(request(), "com.test")
        assertNotNull(outcome.mock)
        assertEquals(418, outcome.mock!!.status)
        assertEquals("{\"ok\":true}", String(outcome.mock!!.body))
    }

    @Test
    fun redirectChangesUpstreamTarget() {
        val engine = RewriteEngine()
        engine.load(
            listOf(Rule(id = 3, urlPattern = "*", action = RuleAction.REDIRECT, redirectUrl = "http://10.0.2.2:8080"))
        )
        val req = request()
        engine.applyRequest(req, "com.test")
        assertEquals("http", req.scheme)
        assertEquals("10.0.2.2", req.host)
        assertEquals(8080, req.port)
        assertEquals("/v1/users?id=7", req.target)
    }

    @Test
    fun disabledRulesAreIgnoredAndDelayAccumulates() {
        val engine = RewriteEngine()
        engine.load(
            listOf(
                Rule(id = 4, enabled = false, action = RuleAction.DELAY, delayMs = 500),
                Rule(id = 5, action = RuleAction.DELAY, delayMs = 120)
            )
        )
        val outcome = engine.applyRequest(request(), "com.test")
        assertEquals(120L, outcome.delayMs)
        assertNull(outcome.mock)
    }

    @Test
    fun methodFilterIsRespected() {
        val engine = RewriteEngine()
        engine.load(listOf(Rule(id = 6, method = "POST", action = RuleAction.DELAY, delayMs = 50)))
        assertEquals(0L, engine.applyRequest(request(), "com.test").delayMs)
    }
}
