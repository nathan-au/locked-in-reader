import SwiftUI
import PDFKit

/// PDFKit wrapped for SwiftUI. External links are swallowed so the reader
/// can't be used to open a browser.
struct PDFReaderView: NSViewRepresentable {
    let url: URL
    let startPage: Int
    var onPageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(white: 0.12, alpha: 1)
        view.delegate = context.coordinator

        if let doc = PDFDocument(url: url) {
            view.document = doc
            if startPage > 0, startPage < doc.pageCount, let page = doc.page(at: startPage) {
                view.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: view)

        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFReaderView
        init(_ parent: PDFReaderView) { self.parent = parent }

        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView,
                  let page = view.currentPage,
                  let index = view.document?.index(for: page) else { return }
            parent.onPageChange(index)
        }

        // Implementing this suppresses the default behavior of opening the URL.
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {}
    }
}
