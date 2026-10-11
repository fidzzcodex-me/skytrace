package com.skytrace.proxy

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.selects.select
import kotlinx.coroutines.withTimeoutOrNull

object Relay {
    suspend fun run(
        a: ByteTransport,
        b: ByteTransport,
        onAtoB: (ByteArray) -> Unit,
        onBtoA: (ByteArray) -> Unit
    ) = coroutineScope {
        val j1 = launch { pump(a, b, onAtoB) }
        val j2 = launch { pump(b, a, onBtoA) }
        select<Unit> {
            j1.onJoin { }
            j2.onJoin { }
        }
        withTimeoutOrNull(2000) { joinAll(j1, j2) }
        a.close()
        b.close()
        j1.cancel()
        j2.cancel()
    }

    private suspend fun pump(src: ByteTransport, dst: ByteTransport, on: (ByteArray) -> Unit) {
        try {
            while (true) {
                val data = src.read() ?: break
                on(data)
                dst.write(data)
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return
        }
    }
}
