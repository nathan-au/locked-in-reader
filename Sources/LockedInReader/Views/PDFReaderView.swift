import SwiftUI
import PDFKit

/// PDFKit wrapped for SwiftUI. External links are swallowed so the reader
/// can't be used to open a browser.
struct PDFReaderView: NSViewRepresentable {
    let url: URL
    let startPage: Int
    var onLoad: (Int) -> Void
    var onPageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PDFView {
        let view = FitPageView()
        view.autoScales = false
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(white: 0.12, alpha: 1)
        view.delegate = context.coordinator

        if let doc = PDFDocument(url: url) {
            view.document = doc
            onLoad(doc.pageCount)
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

/// Sizes the first page to fit entirely on screen (height or width, whichever
/// is tighter) and refits when the window size changes. Pinch/zoom still works.
final class FitPageView: PDFView {
    private var lastFittedSize = NSSize.zero

    override func layout() {
        super.layout()
        guard bounds.size != lastFittedSize, bounds.height > 0, bounds.width > 0,
              let page = document?.page(at: 0) else { return }
        lastFittedSize = bounds.size

        let box = page.bounds(for: displayBox)
        guard box.width > 0, box.height > 0 else { return }
        let fit = min((bounds.height - 12) / box.height, (bounds.width - 12) / box.width)
        minScaleFactor = fit * 0.5
        maxScaleFactor = max(fit * 4, 4)
        scaleFactor = fit
        if let current = currentPage { go(to: current) }
    }
}
