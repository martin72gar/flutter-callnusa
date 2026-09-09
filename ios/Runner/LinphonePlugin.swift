import Flutter
import linphonesw

/// Liblinphone bridge for the Dart `LinphoneService`.
///
/// Mirrors `android/.../LinphonePlugin.kt` method for method; the two must stay
/// in sync because a single Dart contract sits on top of both.
///
/// Incoming calls while the app is terminated arrive as a PushKit VoIP push
/// handled by `flutter_callkit_incoming`; iOS then keeps the process alive long
/// enough for the Core to receive the INVITE that follows.
class LinphonePlugin: NSObject, FlutterStreamHandler {

    static let methodChannel = "id.callnusa/linphone"
    static let eventChannel = "id.callnusa/linphone/events"

    private var core: Core?
    private var events: FlutterEventSink?
    private var coreDelegate: CoreDelegateStub?

    /// Liblinphone has no stable pre-connection call id, so one is minted per
    /// call and shared with Dart and CallKit.
    private var callIds: [Call: String] = [:]

    private func id(for call: Call) -> String {
        if let existing = callIds[call] { return existing }
        let generated = UUID().uuidString
        callIds[call] = generated
        return generated
    }

    private func call(for id: String?) -> Call? {
        callIds.first { $0.value == id }?.key
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments _: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        events = eventSink
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        events = nil
        return nil
    }

    private func emit(_ payload: [String: Any?]) {
        DispatchQueue.main.async { self.events?(payload) }
    }

    // MARK: - Method channel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        do {
            switch call.method {
            case "initialize":
                try initialize(
                    userAgent: args["userAgent"] as? String,
                    verbose: args["verbose"] as? Bool ?? false
                )
                result(nil)

            case "setAccount":
                try setAccount(args)
                result(nil)

            case "clearAccount":
                clearAccount()
                result(nil)

            case "refreshRegistration":
                core?.refreshRegisters()
                result(nil)

            case "setNetworkReachable":
                core?.networkReachable = args["reachable"] as? Bool ?? true
                result(nil)

            case "startCall":
                result(try startCall(destination: args["destination"] as? String))

            case "acceptCall":
                try withCall(args, result) { try $0.accept() }

            case "declineCall":
                try withCall(args, result) { try $0.decline(reason: .Declined) }

            case "endCall":
                try withCall(args, result) { try $0.terminate() }

            case "setMuted":
                try withCall(args, result) { $0.microphoneMuted = args["muted"] as? Bool ?? false }

            case "setHeld":
                try withCall(args, result) {
                    if args["held"] as? Bool == true { try $0.pause() } else { try $0.resume() }
                }

            case "setAudioRoute":
                setAudioRoute(args["route"] as? String)
                result(nil)

            case "sendDtmf":
                try withCall(args, result) {
                    if let digit = (args["digit"] as? String)?.first {
                        try $0.sendDtmf(dtmf: CChar(digit.asciiValue ?? 0))
                    }
                }

            case "dispose":
                core?.stop()
                core = nil
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        } catch {
            // Only the error type is returned: liblinphone messages can contain
            // the proxy URI and SIP headers.
            result(FlutterError(code: "SIP_ERROR", message: "\(type(of: error))", details: nil))
        }
    }

    private func withCall(
        _ args: [String: Any],
        _ result: @escaping FlutterResult,
        _ action: (Call) throws -> Void
    ) throws {
        guard let target = call(for: args["callId"] as? String) else {
            result(FlutterError(code: "CALL_NOT_FOUND", message: "No such call", details: nil))
            return
        }
        try action(target)
        result(nil)
    }

    // MARK: - Core

    private func initialize(userAgent: String?, verbose: Bool) throws {
        guard core == nil else { return }

        let factory = Factory.Instance
        factory.enableLogCollection(state: verbose ? .Enabled : .Disabled)

        let core = try factory.createCore(configPath: nil, factoryConfigPath: nil, systemContext: nil)
        if let userAgent { core.setUserAgent(name: userAgent, version: nil) }

        // CallKit owns the ringtone and the audio session.
        core.callkitEnabled = true
        core.pushNotificationEnabled = true
        core.nativeRingingEnabled = false

        let delegate = CoreDelegateStub(
            onCallStateChanged: { [weak self] (_, call, state, _) in
                self?.onCallState(call, state)
            },
            onAccountRegistrationStateChanged: { [weak self] (_, account, state, message) in
                self?.onRegistrationState(account, state, message)
            }
        )
        core.addDelegate(delegate: delegate)
        coreDelegate = delegate

        try core.start()
        self.core = core
    }

    private func onRegistrationState(
        _ account: Account,
        _ state: RegistrationState,
        _ message: String
    ) {
        let authFailure = account.error == .Forbidden || account.error == .Unauthorized
        emit([
            "type": "registration",
            "state": {
                switch state {
                case .Progress: return "progress"
                case .Ok: return "ok"
                case .Refreshing: return "refreshing"
                case .Failed: return "failed"
                case .Cleared: return "cleared"
                default: return "none"
                }
            }(),
            "reason": message,
            "authFailure": authFailure,
        ])
    }

    private func onCallState(_ call: Call, _ state: Call.State) {
        let callId = id(for: call)
        emit([
            "type": "call",
            "callId": callId,
            "isIncoming": call.dir == .Incoming,
            "remoteNumber": call.remoteAddress?.username ?? "",
            "remoteName": call.remoteAddress?.displayName ?? "",
            "state": {
                switch state {
                case .IncomingReceived, .IncomingEarlyMedia: return "incoming"
                case .OutgoingInit, .OutgoingProgress: return "outgoing_init"
                case .OutgoingRinging: return "outgoing_ringing"
                case .OutgoingEarlyMedia: return "outgoing_early_media"
                case .Connected, .StreamsRunning, .Resuming: return "connected"
                case .Paused, .PausedByRemote: return "paused"
                case .End: return "ended"
                case .Released: return "released"
                case .Error: return "error"
                default: return "unknown"
                }
            }(),
            "reason": {
                switch call.reason {
                case .Busy: return "busy"
                case .Declined: return "declined"
                case .NotFound: return "not_found"
                case .NotAnswered: return "no_answer"
                case .None: return "normal"
                default: return "error"
                }
            }(),
        ])

        if state == .Released { callIds.removeValue(forKey: call) }
    }

    private func setAccount(_ args: [String: Any]) throws {
        guard let core else { return }
        let factory = Factory.Instance

        let domain = args["domain"] as! String
        let username = args["username"] as! String
        let password = args["password"] as! String
        let transport = args["transport"] as? String ?? "tls"
        let port = args["port"] as? Int ?? 5061
        let srtp = args["srtp"] as? String ?? "mandatory"
        let codecs = (args["codecs"] as? [String] ?? ["opus", "pcmu", "pcma"]).map { $0.lowercased() }
        let expires = args["expires"] as? Int ?? 600
        let proxyHost = args["proxy"] as? String ?? domain

        // Replace, never accumulate: a stale account would keep re-registering.
        core.clearAccounts()
        core.clearAllAuthInfo()

        let authInfo = try factory.createAuthInfo(
            username: username, userid: nil, passwd: password,
            ha1: nil, realm: nil, domain: domain
        )
        core.addAuthInfo(info: authInfo)

        let params = try core.createAccountParams()
        try params.setIdentityaddress(newValue: try factory.createAddress(addr: "sip:\(username)@\(domain)"))

        let server = try factory.createAddress(addr: "sip:\(proxyHost):\(port)")
        try server.setTransport(newValue: {
            switch transport {
            case "tcp": return .Tcp
            case "udp": return .Udp
            default: return .Tls
            }
        }())
        try params.setServeraddress(newValue: server)
        params.registerEnabled = true
        params.expires = expires
        params.pushNotificationAllowed = true

        let account = try core.createAccount(params: params)
        try core.addAccount(account: account)
        core.defaultAccount = account

        core.mediaEncryption = srtp == "disabled" ? .None : .SRTP
        core.mediaEncryptionMandatory = srtp == "mandatory"

        for payload in core.audioPayloadTypes {
            _ = payload.enable(enabled: codecs.contains(payload.mimeType.lowercased()))
        }
    }

    private func clearAccount() {
        core?.clearAccounts()
        core?.clearAllAuthInfo()
    }

    private func startCall(destination: String?) throws -> String {
        guard let core else { throw LinphoneError.exception(result: "Core not started") }
        guard let destination, !destination.isEmpty else {
            throw LinphoneError.exception(result: "Empty destination")
        }
        let domain = core.defaultAccount?.params?.identityAddress?.domain ?? ""
        let uri = destination.hasPrefix("sip:") ? destination : "sip:\(destination)@\(domain)"

        guard let call = core.invite(url: uri) else {
            throw LinphoneError.exception(result: "Core refused the invite")
        }
        return id(for: call)
    }

    private func setAudioRoute(_ route: String?) {
        guard let core else { return }
        let type: AudioDeviceType = {
            switch route {
            case "speaker": return .Speaker
            case "bluetooth": return .Bluetooth
            case "headset": return .Headphones
            default: return .Microphone
            }
        }()
        if let device = core.audioDevices.first(where: { $0.type == type && $0.hasCapability(capability: .CapabilityPlay) }) {
            core.outputAudioDevice = device
        }
    }
}
