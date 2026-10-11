package com.skytrace.util

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object EventBus {
    private val mutable = MutableSharedFlow<String>(
        replay = 0,
        extraBufferCapacity = 1024,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )

    val events: SharedFlow<String> = mutable.asSharedFlow()

    fun emit(type: String, payload: JsonElement) {
        val obj: JsonObject = buildJsonObject {
            put("type", type)
            put("data", payload)
        }
        mutable.tryEmit(obj.toString())
    }
}
