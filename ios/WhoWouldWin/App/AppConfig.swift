// AppConfig.swift
// Change backendBaseURL to your deployed backend URL before submitting to App Store.
// For local development on your Mac, use "http://localhost:3000"
enum AppConfig {
    static let backendBaseURL = "http://192.168.111.11:3000"  // your Mac's IP — phone must be on same WiFi
    // For production, replace with your Railway URL e.g.:
    // static let backendBaseURL = "https://your-app.railway.app"
}
