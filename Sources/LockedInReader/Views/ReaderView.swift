import SwiftUI

/// The locked screen: the PDF, a dim countdown, and a hidden emergency-exit prompt.
struct ReaderView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let session = model.session {
                PDFReaderView(
                    url: session.pdfURL,
                    startPage: model.startPage,
                    onLoad: { model.documentLoaded(pageCount: $0) },
                    onPageChange: { model.pageChanged(to: $0) })
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(format(model.remaining))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                if model.totalPages > 0 {
                    Text("\(model.currentPage + 1) / \(model.totalPages)")
                        .font(.system(size: 13, design: .monospaced))
                }
                Text("⌃⌥⌘U emergency exit")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .padding(14)
            .allowsHitTesting(false)

            if model.showUnlockPrompt {
                UnlockPrompt(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.7))
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

/// Passphrase gate for the emergency exit. Wrong guesses trigger a short lockout.
struct UnlockPrompt: View {
    @ObservedObject var model: AppModel
    @State private var attempt = ""
    @State private var message = ""
    @State private var lockedUntil = Date.distantPast
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text("Emergency exit").font(.title2.bold())
            Text("Enter your passphrase to end the session early.")
                .foregroundStyle(.secondary)
            SecureField("Passphrase", text: $attempt)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .focused($focused)
                .onSubmit(submit)
            if !message.isEmpty { Text(message).foregroundStyle(.red).font(.callout) }
            HStack {
                Button("Cancel") { model.showUnlockPrompt = false }
                Button("Exit session", action: submit).keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear { focused = true }
    }

    private func submit() {
        if Date() < lockedUntil {
            message = "Too many attempts. Wait a few seconds."
            return
        }
        if !model.tryEmergencyExit(with: attempt) {
            attempt = ""
            message = "Wrong passphrase."
            lockedUntil = Date().addingTimeInterval(3)
        }
    }
}
