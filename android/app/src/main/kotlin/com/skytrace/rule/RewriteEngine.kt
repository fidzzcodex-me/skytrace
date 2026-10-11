package com.skytrace.rule

import com.skytrace.proxy.Header
import com.skytrace.proxy.HttpRequestMsg
import com.skytrace.proxy.HttpResponseMsg
import com.skytrace.proxy.removeHeader
import com.skytrace.proxy.setHeader
import com.skytrace.proxy.statusReason
import com.skytrace.util.Logger
import com.skytrace.util.globToRegex
import java.io.ByteArrayInputStream
import java.net.URI
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.GZIPInputStream
import java.util.zip.InflaterInputStream

class RequestOutcome(
    val modified: Boolean,
    val mock: HttpResponseMsg?,
    val delayMs: Long
)

class RewriteEngine {
    @Volatile
    private var rules: List<Rule> = emptyList()
    private val regexCache = ConcurrentHashMap<String, Regex>()

    fun load(newRules: List<Rule>) {
        rules = newRules.filter { it.enabled }
        regexCache.clear()
    }

    fun activeCount(): Int = rules.size

    fun matchesRequestRule(rule: Rule, method: String, url: String, appPackage: String): Boolean {
        if (rule.method != "*" && !rule.method.equals(method, ignoreCase = true)) return false
        if (rule.appPackage.isNotBlank() && rule.appPackage != appPackage) return false
        return urlMatches(rule.urlPattern, rule.isRegex, url)
    }

    fun urlMatches(pattern: String, isRegex: Boolean, url: String): Boolean {
        if (pattern.isBlank() || pattern == "*") return true
        val key = (if (isRegex) "r:" else "g:") + pattern
        val regex = regexCache.getOrPut(key) {
            try {
                if (isRegex) Regex(pattern, RegexOption.IGNORE_CASE) else pattern.globToRegex()
            } catch (e: Exception) {
                Logger.w("invalid pattern $pattern", e)
                Regex("$^")
            }
        }
        if (regex.containsMatchIn(url)) return true
        val noScheme = url.substringAfter("://", url)
        return regex.containsMatchIn(noScheme)
    }

    fun needsResponseBuffer(req: HttpRequestMsg, appPackage: String): Boolean {
        val url = req.url()
        return rules.any {
            it.action == RuleAction.REPLACE_BODY &&
                it.phase == RulePhase.RESPONSE &&
                matchesRequestRule(it, req.method, url, appPackage)
        }
    }

    fun applyRequest(req: HttpRequestMsg, appPackage: String): RequestOutcome {
        var modified = false
        var delay = 0L
        val originalUrl = req.url()
        for (rule in rules) {
            if (!matchesRequestRule(rule, req.method, originalUrl, appPackage)) continue
            when (rule.action) {
                RuleAction.MOCK -> {
                    val body = rule.mockBody.toByteArray(Charsets.UTF_8)
                    val headers = mutableListOf(Header("Content-Type", rule.mockContentType))
                    headers.addAll(rule.mockHeaders)
                    headers.add(Header("X-SkyTrace-Mock", rule.name.ifBlank { "rule-${rule.id}" }))
                    val resp = HttpResponseMsg("HTTP/1.1", rule.mockStatus, statusReason(rule.mockStatus), headers, body)
                    return RequestOutcome(true, resp, delay)
                }
                RuleAction.REDIRECT -> if (applyRedirect(req, rule)) modified = true
                RuleAction.MODIFY_HEADER -> if (rule.phase == RulePhase.REQUEST) {
                    applyHeaderRule(req.headers, rule)
                    modified = true
                }
                RuleAction.REPLACE_BODY -> if (rule.phase == RulePhase.REQUEST) {
                    val changed = replaceBody(req.headers, req.body, rule)
                    if (changed != null) {
                        req.body = changed
                        modified = true
                    }
                }
                RuleAction.DELAY -> if (rule.phase == RulePhase.REQUEST) delay += rule.delayMs
            }
        }
        return RequestOutcome(modified, null, delay)
    }

    fun applyResponseHeaders(req: HttpRequestMsg, resp: HttpResponseMsg, appPackage: String): Pair<Boolean, Long> {
        var modified = false
        var delay = 0L
        val url = req.url()
        for (rule in rules) {
            if (rule.phase != RulePhase.RESPONSE) continue
            if (!matchesRequestRule(rule, req.method, url, appPackage)) continue
            when (rule.action) {
                RuleAction.MODIFY_HEADER -> {
                    applyHeaderRule(resp.headers, rule)
                    modified = true
                }
                RuleAction.DELAY -> delay += rule.delayMs
                else -> Unit
            }
        }
        return Pair(modified, delay)
    }

    fun applyResponseBody(req: HttpRequestMsg, resp: HttpResponseMsg, appPackage: String): Boolean {
        var modified = false
        val url = req.url()
        for (rule in rules) {
            if (rule.action != RuleAction.REPLACE_BODY || rule.phase != RulePhase.RESPONSE) continue
            if (!matchesRequestRule(rule, req.method, url, appPackage)) continue
            val changed = replaceBody(resp.headers, resp.body, rule)
            if (changed != null) {
                resp.body = changed
                modified = true
            }
        }
        return modified
    }

    private fun applyRedirect(req: HttpRequestMsg, rule: Rule): Boolean {
        if (rule.redirectUrl.isBlank()) return false
        return try {
            val target = URI(rule.redirectUrl.trim())
            val scheme = target.scheme ?: return false
            val host = target.host ?: return false
            val port = if (target.port > 0) target.port else if (scheme == "https") 443 else 80
            req.scheme = scheme
            req.host = host
            req.port = port
            val newPath = target.rawPath
            if (!newPath.isNullOrEmpty() && newPath != "/") {
                val query = if (target.rawQuery != null) "?${target.rawQuery}" else req.target.substringAfter('?', "").let { if (it.isEmpty()) "" else "?$it" }
                req.target = newPath + query
            }
            req.headers.setHeader("Host", req.hostHeader())
            true
        } catch (e: Exception) {
            Logger.w("redirect rule failed", e)
            false
        }
    }

    private fun applyHeaderRule(headers: MutableList<Header>, rule: Rule) {
        if (rule.headerName.isBlank()) return
        when (rule.headerOp.lowercase()) {
            "remove" -> headers.removeHeader(rule.headerName)
            "add" -> headers.add(Header(rule.headerName, rule.headerValue))
            else -> headers.setHeader(rule.headerName, rule.headerValue)
        }
    }

    private fun replaceBody(headers: MutableList<Header>, body: ByteArray, rule: Rule): ByteArray? {
        if (rule.bodyFind.isEmpty() && rule.bodyReplace.isEmpty()) return null
        val encoding = headers.firstOrNull { it.name.equals("Content-Encoding", true) }?.value?.lowercase() ?: ""
        val plain = decodeBody(body, encoding) ?: return null
        val text = String(plain, Charsets.UTF_8)
        val replaced = if (rule.bodyFind.isEmpty()) {
            rule.bodyReplace
        } else if (rule.bodyRegex) {
            try {
                Regex(rule.bodyFind).replace(text, rule.bodyReplace)
            } catch (e: Exception) {
                return null
            }
        } else {
            text.replace(rule.bodyFind, rule.bodyReplace)
        }
        if (replaced == text) return null
        headers.removeHeader("Content-Encoding")
        return replaced.toByteArray(Charsets.UTF_8)
    }

    companion object {
        fun decodeBody(body: ByteArray, encoding: String): ByteArray? {
            return try {
                when {
                    encoding.isEmpty() || encoding == "identity" -> body
                    encoding.contains("gzip") -> GZIPInputStream(ByteArrayInputStream(body)).use { it.readBytes() }
                    encoding.contains("deflate") -> InflaterInputStream(ByteArrayInputStream(body)).use { it.readBytes() }
                    else -> null
                }
            } catch (e: Exception) {
                null
            }
        }
    }
}
