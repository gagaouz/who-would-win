// AppConfig.swift
// Production API lives at api.animal-vs-animal.com (custom domain → Railway).
// For local development on your Mac, use "http://localhost:3000"
import Foundation

enum AppConfig {
    static let backendBaseURL = "https://api.animal-vs-animal.com"
    /// MetricKit payloads stay on-device unless diagnostics are deliberately
    /// enabled for a release and disclosed in App Store privacy answers.
    static let diagnosticsEnabled = false
    /// Public App Store listing — shared alongside battle results so a share is
    /// also a tappable install invite. App ID 6761319389.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6761319389")!
}
