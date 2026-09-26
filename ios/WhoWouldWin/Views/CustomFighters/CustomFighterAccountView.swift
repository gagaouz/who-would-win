import AuthenticationServices
import SwiftUI

struct CustomFighterAccountView: View {
    @ObservedObject private var account = CustomFighterAccount.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    var onSignedIn: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your fighters, saved")
                        .font(Kids.fredoka(28, weight: .bold)).foregroundColor(Kids.ink)
                    Text("Connect a private library to save your creations and restore them on your other devices. Your existing game works without signing in.")
                        .font(Kids.nunito(16, weight: .semibold)).foregroundColor(Kids.inkSoft)
                    if account.isSignedIn {
                        Label("Library connected", systemImage: "checkmark.circle.fill").foregroundColor(Kids.grassDeep)
                        Text("Saved artwork stays available when Premium expires. Premium is required to create new artwork.")
                            .font(Kids.nunito(15, weight: .semibold))
                        Button("Sign out") { Task { await account.signOut() } }
                            .buttonStyle(.bordered).disabled(account.isWorking)
                        Button("Delete fighter library", role: .destructive) { confirmingDelete = true }
                            .buttonStyle(.bordered).disabled(account.isWorking)
                    } else {
                        if account.accountID != nil {
                            Text("Your downloaded fighters are still on this device. Sign in again to restore, create or delete online artwork.")
                                .font(Kids.nunito(15, weight: .semibold))
                            Button("Sign out on this device") { Task { await account.signOut() } }
                                .buttonStyle(.bordered).disabled(account.isWorking)
                        }
                        Text("Sign in with Apple links your library. We don't request your name or email. Creating artwork sends your entered idea to OpenAI; approved artwork is stored privately on our server until you delete it.")
                            .font(Kids.nunito(15, weight: .semibold))
                        Button {
                            Task { await account.beginSignIn(); if account.isSignedIn { onSignedIn?(); dismiss() } }
                        } label: {
                            Label("Sign in with Apple", systemImage: "apple.logo")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .foregroundColor(.white).background(.black, in: RoundedRectangle(cornerRadius: 10))
                        }.disabled(account.isWorking).accessibilityIdentifier("customFighters.signIn")
                    }
                    if account.isWorking { ProgressView().frame(maxWidth: .infinity) }
                    if let privacyURL = URL(string: AppConfig.customFighterBaseURL)?.appendingPathComponent("api/custom-fighters/privacy") {
                        Link("Fighter library privacy", destination: privacyURL)
                            .font(Kids.nunito(15, weight: .bold)).foregroundColor(Kids.grassDeep)
                    }
                    if let error = account.errorMessage { Text(error).font(Kids.nunito(14, weight: .semibold)).foregroundColor(.red).accessibilityIdentifier("customFighters.accountError") }
                }.padding(24)
            }
            .background(Kids.cream).navigationTitle("Fighter library").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete your private fighter library?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete library", role: .destructive) { Task { await account.deleteAccount() } }
            } message: {
                Text("This removes your saved custom artwork from this device and our server. Your game progress and purchases stay intact. It does not cancel Premium.")
            }
        }
    }
}
