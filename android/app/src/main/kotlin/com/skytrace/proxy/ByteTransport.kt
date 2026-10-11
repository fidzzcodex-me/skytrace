package com.skytrace.proxy

interface ByteTransport {
    suspend fun read(): ByteArray?
    suspend fun write(data: ByteArray)
    fun close()
}

class PrefixedTransport(private val prefix: ByteArray, private val delegate: ByteTransport) : ByteTransport {
    private var pending: ByteArray? = prefix

    override suspend fun read(): ByteArray? {
        val p = pending
        if (p != null) {
            pending = null
            return p
        }
        return delegate.read()
    }

    override suspend fun write(data: ByteArray) = delegate.write(data)

    override fun close() = delegate.close()
}
