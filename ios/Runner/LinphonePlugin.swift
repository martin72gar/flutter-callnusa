import Flutter
import linphonesw

/// Liblinphone bridge for the Dart `LinphoneService`.
///
/// Mirrors `android/app/src/main/kotlin/.../LinphonePlugin.kt` method-for-method
/// so both platforms speak the exact same channel contract (see
/// `lib/core/sip/linphone_service.dart`). All Core access happens on the main
/// thread: the Swift wrapper's Core is not thread-safe and iOS schedules its
/// own iterate loop internally once `start()` is called.
///
/// The Core assigns no stable identifier to a call before it is connected, so
/// this class mints a UUID per `Call` and keeps the mapping; Dart, CallKit and
/// PushKit all key on that id.
final class LinphonePlugin: NSObject, CoreDelegate, FlutterStreamHandler {
    static let methodChannel = "id.callnusa/linphone"
    static let eventChannel = "id.callnusa/linphone/events"

    private var core: Core?
    private var eventSink: FlutterEventSink?

    private var callIds: [ObjectIdentifier: String] = [:]
    private var callsById: [String: Call] = [:]

    private struct PluginError: Error {
        let code: String
        let message: String
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func emit(_ payload: [String: Any?]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }

    // MARK: - CoreDelegate

    func onAccountRegistrationStateChanged(
        core: Core, account: Account, state: RegistrationState, message: String
    ) {
        // 401/403/407 mean the device secret was rotated or revoked: Dart
        // re-provisions instead of retrying with a dead password.
        let authFailure = account.error == .Forbidden || account.error == .Unauthorized

        let stateName: String
        switch state {
        case .Progress: stateName = "progress"
        case .Ok: stateName = "ok"
        case .Refreshing: stateName = "refreshing"
        case .Failed: stateName = "failed"
        case .Cleared, .None: stateName = "cleared"
        }

        emit([
            "type": "registration",
            "state": stateName,
            // `message` may name the registrar; it never carries the secret.
            "reason": message,
            "authFailure": authFailure,
        ])
    }

    func onCallStateChanged(core: Core, call: Call, state: Call.State, message: String) {
        let id = idOf(call)
        let incoming = call.dir == .Incoming

        let stateName: String
        switch state {
        case .IncomingReceived, .IncomingEarlyMedia: stateName = "incoming"
        case .OutgoingInit, .OutgoingProgress: stateName = "outgoing_init"
        case .OutgoingRinging: stateName = "outgoing_ringing"
        case .OutgoingEarlyMedia: stateName = "outgoing_early_media"
        case .Connected, .StreamsRunning, .Resuming: stateName = "connected"
        case .Paused, .PausedByRemote: stateName = "paused"
        case .End: stateName = "ended"
        case .Released: stateName = "released"
        case .Error: stateName = "error"
        default: stateName = "unknown"
        }

        let reasonName: String
        switch call.reason {
        case .Busy: reasonName = "busy"
        case .Declined: reasonName = "declined"
        case .NotFound: reasonName = "not_found"
        case .NotAnswered: reasonName = "no_answer"
        case .None: reasonName = "normal"
        default: reasonName = "error"
        }

        emit([
            "type": "call",
            "callId": id,
            "isIncoming": incoming,
            "remoteNumber": call.remoteAddress?.username ?? "",
            "remoteName": call.remoteAddress?.displayName ?? "",
            "state": stateName,
            "reason": reasonName,
        ])

        if state == .Released {
            callIds.removeValue(forKey: ObjectIdentifier(call))
            callsById.removeValue(forKey: id)
        }
    }

    private func idOf(_ call: Call) -> String {
        let key = ObjectIdentifier(call)
        if let existing = callIds[key] { return existing }
        let id = UUID().uuidString
        callIds[key] = id
        callsById[id] = call
        return id
    }

    private func call(for id: String?) -> Call? {
        guard let id else { return nil }
        return callsById[id]
    }

    // MARK: - Method channel

    func handle(_ methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch methodCall.method {
            case "initialize":
                try initialize(
                    userAgent: methodCall.arg("userAgent"),
                    verbose: methodCall.arg("verbose") ?? false
                )
                result(nil)
            case "setAccount":
                try setAccount(methodCall)
                result(nil)
            case "clearAccount":
                clearAccount()
                result(nil)
            case "refreshRegistration":
                core?.refreshRegisters()
                result(nil)
            case "setNetworkReachable":
                core?.networkReachable = methodCall.arg("reachable") ?? true
                result(nil)
            case "startCall":
                result(try startCall(methodCall.arg("destination")))
            case "acceptCall":
                try withCall(methodCall) { try $0.accept() }
                result(nil)
            case "declineCall":
                try withCall(methodCall) { try $0.decline(reason: .Declined) }
                result(nil)
            case "endCall":
                try withCall(methodCall) { try $0.terminate() }
                result(nil)
            case "setMuted":
                try withCall(methodCall) { $0.microphoneMuted = methodCall.arg("muted") ?? false }
                result(nil)
            case "setHeld":
                try withCall(methodCall) {
                    if methodCall.arg("held") == true { try $0.pause() } else { try $0.resume() }
                }
                result(nil)
            case "setAudioRoute":
                setAudioRoute(methodCall.arg("route"))
                result(nil)
            case "sendDtmf":
                try withCall(methodCall) {
                    let digit: String = methodCall.arg("digit") ?? " "
                    try $0.sendDtmf(dtmf: CChar(bitPattern: digit.utf8.first ?? 32))
                }
                result(nil)
            case "dispose":
                core?.stop()
                core = nil
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        } catch let error as PluginError {
            result(FlutterError(code: error.code, message: error.message, details: nil))
        } catch {
            // Never echo the underlying error verbatim: liblinphone errors can
            // include the SIP proxy URI and headers.
            result(FlutterError(code: "SIP_ERROR", message: "\(type(of: error))", details: nil))
        }
    }

    private func withCall(_ methodCall: FlutterMethodCall, _ action: (Call) throws -> Void) throws {
        guard let target = call(for: methodCall.arg("callId")) else {
            throw PluginError(code: "CALL_NOT_FOUND", message: "No such call")
        }
        try action(target)
    }

    private func initialize(userAgent: String?, verbose: Bool) throws {
        if core != nil { return }

        LoggingService.Instance.domain = "CallNusa"
        LoggingService.Instance.logLevel = verbose ? .Message : .Error

        let factory = Factory.Instance
        let newCore = try factory.createCore(configPath: nil, factoryConfigPath: nil, systemContext: nil)
        newCore.addDelegate(delegate: self)
        if let userAgent { newCore.setUserAgent(name: userAgent, version: nil) }
        // Push-driven wake-ups replace aggressive keepalives; CallKit owns the
        // ringtone so the Core must not ring natively.
        newCore.pushNotificationEnabled = true
        newCore.nativeRingingEnabled = false
        try newCore.start()
        core = newCore
    }

    private func setAccount(_ methodCall: FlutterMethodCall) throws {
        guard let core else {
            throw PluginError(code: "NOT_INITIALIZED", message: "Core not started")
        }
        guard
            let domain: String = methodCall.arg("domain"),
            let username: String = methodCall.arg("username"),
            let password: String = methodCall.arg("password")
        else {
            throw PluginError(code: "INVALID_ARGUMENT", message: "Missing account fields")
        }
        let transport: String = methodCall.arg("transport") ?? "tls"
        let port: Int = methodCall.arg("port") ?? 5061
        let srtp: String = methodCall.arg("srtp") ?? "mandatory"
        let codecs: [String] = methodCall.arg("codecs") ?? ["opus", "pcmu", "pcma"]
        let expirySeconds: Int = methodCall.arg("expires") ?? 600
        let displayName: String? = methodCall.arg("display_name")
        let proxyHost: String = methodCall.arg("proxy") ?? domain

        // Replace any previous account rather than accumulating registrations.
        core.clearAccounts()
        core.clearAllAuthInfo()

        let factory = Factory.Instance
        core.addAuthInfo(info: try factory.createAuthInfo(
            username: username, userid: nil, passwd: password, ha1: nil, realm: nil, domain: domain
        ))

        let transportType: TransportType
        switch transport {
        case "tcp": transportType = .Tcp
        case "udp": transportType = .Udp
        default: transportType = .Tls
        }

        let params = try core.createAccountParams()

        let identityAddress = try factory.createAddress(addr: "sip:\(username)@\(domain)")
        if let displayName, !displayName.isEmpty {
            try identityAddress.setDisplayname(newValue: displayName)
        }
        try params.setIdentityaddress(newValue: identityAddress)

        let serverAddress = try factory.createAddress(addr: "sip:\(proxyHost):\(port)")
        try serverAddress.setTransport(newValue: transportType)
        try params.setServeraddress(newValue: serverAddress)

        params.registerEnabled = true
        params.expires = expirySeconds
        // Keeps the registration binding alive across NAT rebinds.
        params.outboundProxyEnabled = true

        let account = try core.createAccount(params: params)
        try core.addAccount(account: account)
        core.defaultAccount = account

        try core.setMediaencryption(newValue: srtp == "disabled" ? .None : .SRTP)
        core.mediaEncryptionMandatory = srtp == "mandatory"

        applyCodecs(core, codecs)
    }

    /// Enables exactly the offered codecs, in the backend's preference order.
    private func applyCodecs(_ core: Core, _ codecs: [String]) {
        let wanted = Set(codecs.map { $0.lowercased() })
        for payload in core.audioPayloadTypes {
            _ = payload.enable(enabled: wanted.contains(payload.mimeType.lowercased()))
        }
    }

    private func clearAccount() {
        guard let core else { return }
        if let account = core.defaultAccount, let params = account.params?.clone() {
            params.registerEnabled = false
            account.params = params
        }
        core.clearAccounts()
        core.clearAllAuthInfo()
    }

    private func startCall(_ destination: String?) throws -> String {
        guard let core else {
            throw PluginError(code: "NOT_INITIALIZED", message: "Core not started")
        }
        guard let destination, !destination.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PluginError(code: "INVALID_DESTINATION", message: "Empty destination")
        }
        let domain = core.defaultAccount?.params?.identityAddress?.domain
        let uri = destination.hasPrefix("sip:") ? destination : "sip:\(destination)@\(domain ?? "")"
        guard let address = try? Factory.Instance.createAddress(addr: uri) else {
            throw PluginError(code: "INVALID_DESTINATION", message: "Not a valid SIP address")
        }

        let callParams = try core.createCallParams(call: nil)
        guard let call = core.inviteAddressWithParams(addr: address, params: callParams) else {
            throw PluginError(code: "CALL_NOT_STARTED", message: "Core refused the invite")
        }
        return idOf(call)
    }

    private func setAudioRoute(_ route: String?) {
        guard let core else { return }
        let kind: AudioDevice.Kind
        switch route {
        case "speaker": kind = .Speaker
        case "bluetooth": kind = .Bluetooth
        case "headset": kind = .Headphones
        default: kind = .Earpiece
        }
        if let device = core.audioDevices.first(where: {
            $0.type == kind && $0.hasCapability(capability: .CapabilityPlay)
        }) {
            core.outputAudioDevice = device
        }
    }
}

private extension FlutterMethodCall {
    func arg<T>(_ key: String) -> T? {
        (arguments as? [String: Any])?[key] as? T
    }
}
