import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

/// Crash & hang reporting via Apple's first-party MetricKit — COPPA-safe (no
/// third-party SDK, no PII, aggregated on-device by the OS). The app was
/// previously BLIND to crashes; this forwards crash/hang diagnostics to our
/// backend (`/api/diag`, which just logs them) so failures are visible in
/// Railway logs without waiting on Xcode Organizer.
final class CrashReportingService: NSObject {
    static let shared = CrashReportingService()

    func start() {
        guard AppConfig.diagnosticsEnabled else { return }
        #if canImport(MetricKit)
        if #available(iOS 14.0, *) {
            MXMetricManager.shared.add(self)
        }
        #endif
    }

    private func send(_ body: Data) {
        guard AppConfig.diagnosticsEnabled else { return }
        guard let url = URL(string: AppConfig.backendBaseURL + "/api/diag") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
    }

    /// COPPA hardening: a MetricKit payload's `metaData` carries fields that could
    /// help fingerprint a specific child's device — the exact hardware model and
    /// the device's locale/region. We don't need those for crash triage (OS
    /// version + app build are enough), so strip them recursively before sending.
    /// Returns the scrubbed JSON, or the original data if parsing fails.
    private static let strippedMetadataKeys: Set<String> = [
        "deviceType", "regionFormat", "lowPowerModeEnabled",
    ]
    fileprivate func scrubbed(_ data: Data) -> Data {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return data }
        let cleaned = Self.scrub(obj)
        return (try? JSONSerialization.data(withJSONObject: cleaned)) ?? data
    }
    private static func scrub(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (k, v) in dict where !strippedMetadataKeys.contains(k) {
                out[k] = scrub(v)
            }
            return out
        }
        if let arr = value as? [Any] {
            return arr.map { scrub($0) }
        }
        return value
    }
}

#if canImport(MetricKit)
@available(iOS 14.0, *)
extension CrashReportingService: MXMetricManagerSubscriber {
    // Performance metrics — not needed for crash visibility; ignore.
    func didReceive(_ payloads: [MXMetricPayload]) {}

    // Crash / hang / disk-write / CPU-exception diagnostics.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            // Only forward payloads that actually contain a crash or hang — skip
            // routine performance diagnostics so we don't spam the backend.
            let hasCrash = !(payload.crashDiagnostics?.isEmpty ?? true)
            let hasHang  = !(payload.hangDiagnostics?.isEmpty ?? true)
            guard hasCrash || hasHang else { continue }
            send(scrubbed(payload.jsonRepresentation()))
        }
    }
}
#endif
