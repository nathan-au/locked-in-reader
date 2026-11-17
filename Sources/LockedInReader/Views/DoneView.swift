import SwiftUI

struct DoneView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            let s = model.summary
            Image(systemName: s?.outcome == .completed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(s?.outcome == .completed ? .green : .orange)
            Text(s?.outcome == .completed ? "Session complete" : "Exited early")
                .font(.largeTitle.bold())
            if let s {
                VStack(spacing: 12) {
                    stat("PDF", s.pdfName)
                    stat("Time", "\(Int(s.elapsed / 60)) min")
                }.padding(.top, 6)
            }
            HStack {
                Button("New session") { model.newSession() }.keyboardShortcut(.defaultAction)
                Button("Quit") { NSApp.terminate(nil) }
            }.padding(.top, 8)
        }
        .padding(36)
        .frame(width: 440)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack { Text(value).font(.title2.bold()).lineLimit(1).truncationMode(.middle); Text(label).font(.caption).foregroundStyle(.secondary) }
    }
}
