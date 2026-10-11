package com.skytrace.rule

import com.skytrace.proxy.Header
import kotlinx.serialization.Serializable

@Serializable
enum class RuleAction { REDIRECT, MODIFY_HEADER, REPLACE_BODY, MOCK, DELAY }

@Serializable
enum class RulePhase { REQUEST, RESPONSE }

@Serializable
data class Rule(
    val id: Long = 0,
    val name: String = "",
    val enabled: Boolean = true,
    val urlPattern: String = "*",
    val isRegex: Boolean = false,
    val method: String = "*",
    val appPackage: String = "",
    val action: RuleAction = RuleAction.MODIFY_HEADER,
    val phase: RulePhase = RulePhase.REQUEST,
    val redirectUrl: String = "",
    val headerOp: String = "set",
    val headerName: String = "",
    val headerValue: String = "",
    val bodyFind: String = "",
    val bodyReplace: String = "",
    val bodyRegex: Boolean = false,
    val mockStatus: Int = 200,
    val mockBody: String = "",
    val mockContentType: String = "application/json",
    val mockHeaders: List<Header> = emptyList(),
    val delayMs: Long = 0
)

@Serializable
data class Breakpoint(
    val id: Long = 0,
    val name: String = "",
    val enabled: Boolean = true,
    val urlPattern: String = "*",
    val isRegex: Boolean = false,
    val method: String = "*",
    val onRequest: Boolean = true,
    val onResponse: Boolean = false
)
