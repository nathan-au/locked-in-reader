import SwiftUI
import AppKit

struct SetupView: View {
    @ObservedObject var model: AppModel
    private let presets = [15, 25, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Locked In Reader").font(.largeTitle.bold())
            Text("Your Mac stays locked to this PDF until the timer ends.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("PDF") {
                HStack {
                    Text(model.pdfURL?.lastPathComponent ?? "No file chosen")
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(model.pdfURL == nil ? .secondary : .primary)
                    Spacer()
                    Button("Choose…", action: choosePDF)
                }.padding(6)
            }

            GroupBox("Duration") {
                HStack {
                    ForEach(presets, id: \.self) { m in
                        Button("\(m)m") { model.durationMinutes = m }
                            .buttonStyle(.bordered)
                            .tint(model.durationMinutes == m ? .accentColor : nil)
                    }
                    Spacer()
                    TextField("Minutes", value: $model.durationMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("min")
                }.padding(6)
            }

            GroupBox("Emergency passphrase") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("At least \(AppModel.minPassphraseLength) characters", text: $model.passphrase)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Generate") { model.passphrase = Self.generatePassphrase() }
                    }
                    Text("Your only early exit (⌃⌥⌘U). Write it down; it can't be recovered.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(6)
            }

            HStack {
                Spacer()
                Button("Start locked session") { confirmAndStart() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .disabled(!model.canStart)
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private func choosePDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { model.pdfURL = panel.url }
    }

    private func confirmAndStart() {
        let alert = NSAlert()
        alert.messageText = "Lock your Mac for \(model.durationMinutes) minutes?"
        alert.informativeText = "You won't be able to switch apps or quit until the timer ends. Your passphrase is the only early exit."
        alert.addButton(withTitle: "Lock in")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { model.startSession() }
    }

    /// Four random words, shown in the field so the user can copy it out.
    static func generatePassphrase() -> String {
        let words = ["amber", "bridge", "candle", "delta", "ember", "falcon", "granite", "harbor",
                     "island", "juniper", "kettle", "lantern", "meadow", "nectar", "orchid", "pebble",
                     "quartz", "river", "saddle", "thistle", "umber", "velvet", "willow", "zephyr"]
        return (0..<4).map { _ in words.randomElement()! }.joined(separator: "-")
    }
}
