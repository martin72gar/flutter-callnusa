package id.callnusa.callnusa_mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.linphone.core.Account
import org.linphone.core.AudioDevice
import org.linphone.core.Call
import org.linphone.core.Core
import org.linphone.core.CoreListenerStub
import org.linphone.core.Factory
import org.linphone.core.LogLevel
import org.linphone.core.MediaEncryption
import org.linphone.core.Reason
import org.linphone.core.RegistrationState
import org.linphone.core.TransportType
import java.util.UUID

/**
 * Liblinphone bridge for the Dart [LinphoneService].
 *
 * All Core access happens on the main thread: liblinphone's Java wrapper is not
 * thread-safe and the Core's own iterate loop runs there.
 *
 * The Core assigns no stable identifier to a call before it is connected, so
 * this class mints a UUID per [Call] and keeps the mapping; Dart, CallKit and
 * the Telecom framework all key on that id.
 */
class LinphonePlugin(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "id.callnusa/linphone"
        const val EVENT_CHANNEL = "id.callnusa/linphone/events"
    }

    private val main = Handler(Looper.getMainLooper())
    private var core: Core? = null
    private var events: EventChannel.EventSink? = null

    private val callIds = mutableMapOf<Call, String>()

    private fun idOf(call: Call): String = callIds.getOrPut(call) { UUID.randomUUID().toString() }

    private fun callFor(id: String?): Call? =
        callIds.entries.firstOrNull { it.value == id }?.key

    private val listener = object : CoreListenerStub() {
        override fun onAccountRegistrationStateChanged(
            core: Core,
            account: Account,
            state: RegistrationState,
            message: String
        ) {
            // 401/403/407 mean the device secret was rotated or revoked: Dart
            // re-provisions instead of retrying with a dead password.
            val authFailure = account.error == Reason.Forbidden ||
                account.error == Reason.Unauthorized

            emit(
                mapOf(
                    "type" to "registration",
                    "state" to when (state) {
                        RegistrationState.Progress -> "progress"
                        RegistrationState.Ok -> "ok"
                        RegistrationState.Refreshing -> "refreshing"
                        RegistrationState.Failed -> "failed"
                        RegistrationState.Cleared -> "cleared"
                        else -> "none"
                    },
                    // `message` may name the registrar; it never carries the secret.
                    "reason" to message,
                    "authFailure" to authFailure
                )
            )
        }

        override fun onCallStateChanged(
            core: Core,
            call: Call,
            state: Call.State,
            message: String
        ) {
            val id = idOf(call)
            val incoming = call.dir == Call.Dir.Incoming

            emit(
                mapOf(
                    "type" to "call",
                    "callId" to id,
                    "isIncoming" to incoming,
                    "remoteNumber" to (call.remoteAddress.username ?: ""),
                    "remoteName" to (call.remoteAddress.displayName ?: ""),
                    "state" to when (state) {
                        Call.State.IncomingReceived,
                        Call.State.IncomingEarlyMedia -> "incoming"
                        Call.State.OutgoingInit,
                        Call.State.OutgoingProgress -> "outgoing_init"
                        Call.State.OutgoingRinging -> "outgoing_ringing"
                        Call.State.OutgoingEarlyMedia -> "outgoing_early_media"
                        Call.State.Connected,
                        Call.State.StreamsRunning,
                        Call.State.Resuming -> "connected"
                        Call.State.Paused,
                        Call.State.PausedByRemote -> "paused"
                        Call.State.End -> "ended"
                        Call.State.Released -> "released"
                        Call.State.Error -> "error"
                        else -> "unknown"
                    },
                    "reason" to when (call.reason) {
                        Reason.Busy -> "busy"
                        Reason.Declined -> "declined"
                        Reason.NotFound -> "not_found"
                        Reason.NotAnswered -> "no_answer"
                        Reason.None -> "normal"
                        else -> "error"
                    }
                )
            )

            if (state == Call.State.Released) callIds.remove(call)
        }
    }

    private fun emit(payload: Map<String, Any?>) = main.post { events?.success(payload) }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> initialize(call.argument<String>("userAgent"), call.argument<Boolean>("verbose") ?: false, call.argument<Boolean>("allowInsecureTls") ?: false, result)
                "setAccount" -> setAccount(call, result)
                "clearAccount" -> clearAccount(result)
                "refreshRegistration" -> {
                    core?.refreshRegisters()
                    result.success(null)
                }
                "setNetworkReachable" -> {
                    core?.isNetworkReachable = call.argument<Boolean>("reachable") ?: true
                    result.success(null)
                }
                "startCall" -> startCall(call.argument<String>("destination"), result)
                "acceptCall" -> withCall(call, result) { it.accept() }
                "declineCall" -> withCall(call, result) { it.decline(Reason.Declined) }
                "endCall" -> withCall(call, result) { it.terminate() }
                "setMuted" -> withCall(call, result) {
                    it.microphoneMuted = call.argument<Boolean>("muted") ?: false
                }
                "setHeld" -> withCall(call, result) {
                    if (call.argument<Boolean>("held") == true) it.pause() else it.resume()
                }
                "setAudioRoute" -> setAudioRoute(call.argument<String>("route"), result)
                "sendDtmf" -> withCall(call, result) {
                    it.sendDtmf((call.argument<String>("digit") ?: " ")[0])
                }
                "dispose" -> {
                    core?.stop()
                    core = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Never echo the exception's cause into Dart verbatim in release:
            // liblinphone can include the SIP proxy URI and headers.
            result.error("SIP_ERROR", e.javaClass.simpleName, null)
        }
    }

    private inline fun withCall(
        call: MethodCall,
        result: MethodChannel.Result,
        action: (Call) -> Unit
    ) {
        val target = callFor(call.argument<String>("callId"))
        if (target == null) {
            result.error("CALL_NOT_FOUND", "No such call", null)
            return
        }
        action(target)
        result.success(null)
    }

    private fun initialize(userAgent: String?, verbose: Boolean, allowInsecureTls: Boolean, result: MethodChannel.Result) {
        if (core != null) {
            result.success(null)
            return
        }
        val factory = Factory.instance()
        factory.setDebugMode(verbose, "CallNusa")
        factory.loggingService.setLogLevel(if (verbose) LogLevel.Message else LogLevel.Error)

        core = factory.createCore(null, null, context).apply {
            addListener(listener)
            if (userAgent != null) setUserAgent(userAgent, null)
            // Push-driven wake-ups replace aggressive keepalives; the Core still
            // needs a short expiry-refresh margin to survive NAT rebinding.
            isPushNotificationEnabled = true
            isNativeRingingEnabled = false // CallKit / Telecom owns the ringtone
            // Dev-only escape hatch (Env.allowInsecureTransport, forced false
            // outside the development flavor): accepts the local Docker
            // Asterisk stack's self-signed TLS certificate without requiring
            // it to be installed as a trusted CA on the device.
            if (allowInsecureTls) {
                verifyServerCertificates(false)
                verifyServerCn(false)
            }
            start()
        }
        result.success(null)
    }

    private fun setAccount(call: MethodCall, result: MethodChannel.Result) {
        val core = this.core ?: run {
            result.error("NOT_INITIALIZED", "Core not started", null)
            return
        }
        val domain = call.argument<String>("domain")!!
        val username = call.argument<String>("username")!!
        val password = call.argument<String>("password")!!
        val transport = call.argument<String>("transport") ?: "tls"
        val port = call.argument<Int>("port") ?: 5061
        val srtp = call.argument<String>("srtp") ?: "mandatory"
        val codecs = call.argument<List<String>>("codecs") ?: listOf("opus", "pcmu", "pcma")
        val expirySeconds = call.argument<Int>("expires") ?: 600
        val displayName = call.argument<String>("display_name")
        val proxyHost = call.argument<String>("proxy") ?: domain

        // Replace any previous account rather than accumulating registrations.
        core.clearAccounts()
        core.clearAllAuthInfo()

        val factory = Factory.instance()
        core.addAuthInfo(
            factory.createAuthInfo(username, null, password, null, null, domain)
        )

        val transportType = when (transport) {
            "tcp" -> TransportType.Tcp
            "udp" -> TransportType.Udp
            else -> TransportType.Tls
        }

        val params = core.createAccountParams().apply {
            identityAddress = factory.createAddress("sip:$username@$domain")?.apply {
                if (!displayName.isNullOrEmpty()) this.displayName = displayName
            }
            serverAddress = factory.createAddress("sip:$proxyHost:$port")?.apply {
                setTransport(transportType)
            }
            isRegisterEnabled = true
            expires = expirySeconds
            // Keeps the registration binding alive across NAT rebinds.
            isOutboundProxyEnabled = true
        }

        val account = core.createAccount(params)
        core.addAccount(account)
        core.defaultAccount = account

        core.mediaEncryption = when (srtp) {
            "disabled" -> MediaEncryption.None
            else -> MediaEncryption.SRTP
        }
        core.isMediaEncryptionMandatory = srtp == "mandatory"

        applyCodecs(core, codecs)
        result.success(null)
    }

    /** Enables exactly the offered codecs, in the backend's preference order. */
    private fun applyCodecs(core: Core, codecs: List<String>) {
        val wanted = codecs.map { it.lowercase() }
        core.audioPayloadTypes.forEach { payload ->
            payload.enable(wanted.contains(payload.mimeType.lowercase()))
        }
    }

    private fun clearAccount(result: MethodChannel.Result) {
        core?.apply {
            defaultAccount?.params?.clone()?.let { params ->
                params.isRegisterEnabled = false
                defaultAccount?.params = params
            }
            clearAccounts()
            clearAllAuthInfo()
        }
        result.success(null)
    }

    private fun startCall(destination: String?, result: MethodChannel.Result) {
        val core = this.core ?: run {
            result.error("NOT_INITIALIZED", "Core not started", null)
            return
        }
        if (destination.isNullOrBlank()) {
            result.error("INVALID_DESTINATION", "Empty destination", null)
            return
        }
        val domain = core.defaultAccount?.params?.identityAddress?.domain
        val address = Factory.instance().createAddress(
            if (destination.startsWith("sip:")) destination else "sip:$destination@$domain"
        ) ?: run {
            result.error("INVALID_DESTINATION", "Not a valid SIP address", null)
            return
        }

        val call = core.inviteAddressWithParams(address, core.createCallParams(null)!!)
        if (call == null) {
            result.error("CALL_NOT_STARTED", "Core refused the invite", null)
            return
        }
        result.success(idOf(call))
    }

    private fun setAudioRoute(route: String?, result: MethodChannel.Result) {
        val core = this.core ?: run {
            result.success(null)
            return
        }
        val type = when (route) {
            "speaker" -> AudioDevice.Type.Speaker
            "bluetooth" -> AudioDevice.Type.Bluetooth
            "headset" -> AudioDevice.Type.Headphones
            else -> AudioDevice.Type.Earpiece
        }
        core.audioDevices
            .firstOrNull { it.type == type && it.hasCapability(AudioDevice.Capabilities.CapabilityPlay) }
            ?.let { core.outputAudioDevice = it }
        result.success(null)
    }
}
