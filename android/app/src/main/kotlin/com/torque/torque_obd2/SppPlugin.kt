package com.torque.torque_obd2

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Bluetooth Classic (SPP / RFCOMM) for the $8 ELM327 adapters everyone already
 * owns. Android reaches them; iOS never can. This module is the whole reason
 * the Android build is commercially different.
 *
 * Contract — SPEC §3.4:
 *   MethodChannel "ktc.torque/spp"
 *     isSupported()      -> Boolean
 *     listPaired()       -> List<Map{name, address, bondState}>
 *     connect(address)   -> Boolean
 *     write(bytes)       -> null
 *     disconnect()       -> null
 *   EventChannel "ktc.torque/spp_stream"
 *     ByteArray chunks, and Map{"event": "disconnected"} on drop
 *   Error codes: unsupported, off, permission, unpaired, argument, io, state
 *
 * Zero protocol parsing happens here. Bytes go up to Dart exactly as the
 * socket delivered them; `ElmSession` frames them on the '>' prompt. Keeping
 * Kotlin dumb is what lets the whole protocol layer stay testable on the VM.
 *
 * Everything that belongs to one connection lives in a [Link], so a read
 * thread left over from a previous link can never close the current one, and
 * a `disconnect` that lands while `BluetoothSocket.connect()` is blocking
 * aborts it instead of being ignored.
 */
class SppPlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "ktc.torque/spp"
        const val EVENT_CHANNEL = "ktc.torque/spp_stream"

        /** The well-known Serial Port Profile UUID. Every ELM327 clone speaks it. */
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        /** Sized for RFCOMM's typical MTU; an ELM327 reply is rarely over 100 bytes. */
        private const val READ_BUFFER = 1024
    }

    /** One RFCOMM connection and the things that only make sense while it lives. */
    private class Link(val socket: BluetoothSocket, val address: String) {
        val alive = AtomicBoolean(true)
        val input: InputStream = socket.inputStream
        val output: OutputStream = socket.outputStream
        @Volatile var receiver: BroadcastReceiver? = null

        /** Closing the socket is what unblocks a read parked on it. */
        fun close() {
            try { input.close() } catch (_: IOException) {}
            try { output.close() } catch (_: IOException) {}
            try { socket.close() } catch (_: IOException) {}
        }
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    /** EventSink and MethodChannel.Result must be driven from the main thread. */
    private val main = Handler(Looper.getMainLooper())

    /**
     * One executor for connect and write, so writes are serialised and never
     * race a connect in progress. Reads get their own Thread — see [startReadLoop].
     */
    private val io = Executors.newSingleThreadExecutor { r -> Thread(r, "spp-io") }

    private val adapter: BluetoothAdapter? by lazy {
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    }

    @Volatile private var sink: EventChannel.EventSink? = null

    /** Guards [link], [pending] and [generation] transitions. */
    private val lock = Any()
    @Volatile private var link: Link? = null

    /** The socket a connect is currently blocked on, so [abort] can cut it short. */
    private var pending: BluetoothSocket? = null

    /**
     * Bumped by every connect and every disconnect, on the platform thread,
     * in call order. A connect that finds the generation moved was superseded
     * or cancelled and throws its socket away rather than publishing a link
     * nobody wants.
     */
    private val generation = AtomicInteger()

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        abort()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        io.shutdownNow()
    }

    // ---------------------------------------------------------------- methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(adapter != null)
            "listPaired" -> listPaired(result)
            "connect" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("argument", "connect needs an address", null)
                } else {
                    connect(address, result)
                }
            }
            "write" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("argument", "write needs bytes", null)
                } else {
                    write(bytes, result)
                }
            }
            "disconnect" -> {
                // Synchronous and cheap: closing the socket is what aborts a
                // blocked connect() or read(); nothing here waits on a thread.
                abort()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Paired devices only. SPP adapters are paired in Android Settings — the
     * in-app pairing PIN flow is a mess across OEMs and the spec forbids it.
     */
    private fun listPaired(result: MethodChannel.Result) {
        val bt = adapter
        if (bt == null) {
            result.error("unsupported", "This device has no Bluetooth adapter", null)
            return
        }
        // bondedDevices is empty whenever the adapter isn't STATE_ON. Without
        // this check "Bluetooth is off" would look like "nothing paired" —
        // the most confusing failure a first-run user can hit.
        if (!bt.isEnabled) {
            result.error("off", "Bluetooth is turned off", null)
            return
        }
        try {
            // Documented to return null on a binder error, e.g. while the
            // Bluetooth process is restarting after a toggle.
            val devices = bt.bondedDevices.orEmpty().map { device ->
                mapOf(
                    "name" to (device.name ?: ""),
                    "address" to device.address,
                    "bondState" to device.bondState,
                )
            }
            result.success(devices)
        } catch (e: SecurityException) {
            // API 31+: BLUETOOTH_CONNECT is a runtime permission. Fail with a
            // code Dart can act on rather than crashing the engine.
            result.error("permission", "Bluetooth permission not granted", e.message)
        }
    }

    private fun connect(rawAddress: String, result: MethodChannel.Result) {
        val bt = adapter
        if (bt == null) {
            result.error("unsupported", "This device has no Bluetooth adapter", null)
            return
        }
        if (!bt.isEnabled) {
            result.error("off", "Bluetooth is turned off", null)
            return
        }
        // getRemoteDevice() rejects lower-case hex outright.
        val address = rawAddress.uppercase(Locale.ROOT)

        // Claim this call's generation here, on the platform thread, in order
        // with abort(). Taken inside the io block instead, a connect still
        // queued behind a blocked one would start AFTER a disconnect and sail
        // past every generation check. This call also supersedes whatever
        // connect is blocking right now, so cut it short rather than waiting
        // 12–30 s behind it.
        val gen: Int
        val stale: BluetoothSocket?
        synchronized(lock) {
            gen = generation.incrementAndGet()
            stale = pending
            pending = null
        }
        try { stale?.close() } catch (_: IOException) {}

        runIo(result) {
            try {
                if (generation.get() != gen) throw IOException("Connect cancelled")
                // One link at a time: drop whatever is there, silently.
                abortLink()

                // SPEC §3.4 rule 1. Discovery saturates the radio and makes
                // connect() fail with "read failed, socket might closed" — the
                // single most common SPP failure in the field.
                try {
                    bt.cancelDiscovery()
                } catch (_: SecurityException) {
                    // Needs BLUETOOTH_SCAN on 31+; not fatal if absent.
                }

                val device = bt.getRemoteDevice(address)

                // A secure RFCOMM connect to an unbonded device makes the OS
                // pop its pairing dialog — the in-app pairing the spec
                // forbids. Refuse with a code the UI can turn into the
                // "pair it in Settings first" card.
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    main.post {
                        result.error("unpaired", "Adapter isn't paired — pair it in Android Settings first", null)
                    }
                    return@runIo
                }

                val sock = openSocket(device, gen)

                val l = Link(sock, address)
                // Publish and register the ACL receiver in one critical
                // section, so an abort() can never find a published link
                // without its receiver and leave that receiver registered
                // forever. registerReceiver is an ActivityManager call, not
                // a Bluetooth-stack call; nothing under `lock` waits on it.
                val published = synchronized(lock) {
                    if (generation.get() == gen) {
                        l.receiver = registerAclReceiver(l)
                        link = l
                        true
                    } else {
                        false
                    }
                }
                if (!published) {
                    // disconnect() landed while we were blocked in connect().
                    l.close()
                    main.post { result.error("io", "Connect cancelled", null) }
                    return@runIo
                }

                startReadLoop(l)
                main.post { result.success(true) }
            } catch (e: SecurityException) {
                main.post { result.error("permission", "Bluetooth permission not granted", e.message) }
            } catch (e: IOException) {
                main.post { result.error("io", "Couldn't connect to the adapter", e.message) }
            } catch (e: IllegalArgumentException) {
                main.post { result.error("argument", "Not a valid Bluetooth address", e.message) }
            }
        }
    }

    /**
     * SPEC §3.4 rule 2. The standard socket first; on failure, the reflection
     * socket on channel 1, which many clones need. The reflection path is on
     * Android's non-SDK greylist and may be refused on newer releases — that
     * is caught and reported as the original IOException.
     *
     * Each socket is parked in [pending] for the duration of its blocking
     * `connect()`, so [abort] can close it from another thread — the only way
     * to cut a 12–30 s connect to an unpowered adapter short.
     */
    @Throws(IOException::class)
    private fun openSocket(device: BluetoothDevice, gen: Int): BluetoothSocket {
        val standard = device.createRfcommSocketToServiceRecord(SPP_UUID)
        try {
            connectPending(standard, gen)
            return standard
        } catch (first: IOException) {
            try { standard.close() } catch (_: IOException) {}

            val fallback = try {
                device.javaClass
                    .getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    .invoke(device, 1) as BluetoothSocket
            } catch (_: Exception) {
                throw first
            }
            try {
                connectPending(fallback, gen)
                return fallback
            } catch (second: IOException) {
                try { fallback.close() } catch (_: IOException) {}
                throw second
            }
        }
    }

    @Throws(IOException::class)
    private fun connectPending(sock: BluetoothSocket, gen: Int) {
        synchronized(lock) {
            if (generation.get() != gen) throw IOException("Connect cancelled")
            pending = sock
        }
        try {
            sock.connect()
        } finally {
            synchronized(lock) { if (pending === sock) pending = null }
        }
    }

    /**
     * SPEC §3.4 rule 3. A dedicated Thread that owns the blocking read. Not a
     * coroutine: `InputStream.read` blocks for as long as the adapter is
     * silent, and a coroutine dispatcher thread parked on it starves everything
     * else scheduled there.
     */
    private fun startReadLoop(l: Link) {
        Thread({
            val buffer = ByteArray(READ_BUFFER)
            try {
                while (l.alive.get()) {
                    val n = l.input.read(buffer)
                    if (n < 0) break
                    if (n > 0) {
                        // SPEC §3.4 rule 4: raw bytes, exactly as read. copyOf
                        // because the buffer is reused on the next iteration.
                        emit(buffer.copyOf(n))
                    }
                }
            } catch (_: IOException) {
                // Socket closed underneath us — expected on disconnect and on
                // adapter loss alike.
            }
            onLinkLost(l)
        }, "spp-read").also { it.isDaemon = true; it.start() }
    }

    /**
     * SPEC §3.4 rule 5. The read loop does not always throw when the link
     * drops — some stacks leave it blocked forever. The ACL broadcast is the
     * reliable signal, filtered to our device so a headset disconnecting
     * doesn't end the OBD session.
     */
    private fun registerAclReceiver(l: Link): BroadcastReceiver {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_ACL_DISCONNECTED) return
                val device: BluetoothDevice? =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                if (device?.address != l.address) return
                onLinkLost(l)
            }
        }
        val filter = IntentFilter(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // EXPORTED, deliberately. The sender is the Bluetooth stack process
            // (uid 1002), not system_server, and a NOT_EXPORTED receiver only
            // accepts root/system senders — the broadcast would be dropped
            // with an "Exported Denial" and rule 5 would be dead on 13+.
            // Exporting adds no spoofing surface: the action is a
            // <protected-broadcast> only the platform can send.
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        return receiver
    }

    private fun write(bytes: ByteArray, result: MethodChannel.Result) {
        runIo(result) {
            val l = link
            if (l == null || !l.alive.get()) {
                main.post { result.error("state", "Not connected", null) }
                return@runIo
            }
            try {
                l.output.write(bytes)
                l.output.flush()
                main.post { result.success(null) }
            } catch (e: IOException) {
                // A failed write is the first sign of a dead link on stacks
                // whose read loop never throws.
                onLinkLost(l)
                main.post { result.error("io", "Write failed", e.message) }
            }
        }
    }

    // --------------------------------------------------------------- teardown

    /**
     * The link went away underneath us — read loop ended, ACL dropped, or a
     * write failed. Whichever observer gets here first reports it; the rest
     * find [Link.alive] already false and do nothing. An explicit disconnect
     * clears `alive` before closing, so it never produces a phantom event.
     */
    private fun onLinkLost(l: Link) {
        if (!l.alive.getAndSet(false)) return
        l.close()
        unregister(l)
        synchronized(lock) { if (link === l) link = null }
        emit(mapOf("event" to "disconnected"))
    }

    /**
     * Explicit disconnect. Invalidates any connect in flight, closes the socket
     * it is blocked on, and drops the current link — all without waiting on
     * another thread, so it is safe from the platform thread.
     */
    private fun abort() {
        val toClose: BluetoothSocket?
        synchronized(lock) {
            generation.incrementAndGet()
            toClose = pending
            pending = null
        }
        try { toClose?.close() } catch (_: IOException) {}
        abortLink()
    }

    /** Drops the current link silently — no "disconnected" event. */
    private fun abortLink() {
        val l = synchronized(lock) { link.also { link = null } } ?: return
        if (!l.alive.getAndSet(false)) return
        l.close()
        unregister(l)
    }

    private fun unregister(l: Link) {
        val r = l.receiver ?: return
        l.receiver = null
        try { context.unregisterReceiver(r) } catch (_: IllegalArgumentException) {}
    }

    /** After [dispose] the executor is gone; answer rather than crash. */
    private fun runIo(result: MethodChannel.Result, block: () -> Unit) {
        try {
            io.execute(block)
        } catch (_: RejectedExecutionException) {
            result.error("state", "Bluetooth module is shut down", null)
        }
    }

    // ----------------------------------------------------------------- events

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emit(payload: Any) {
        main.post { sink?.success(payload) }
    }
}
