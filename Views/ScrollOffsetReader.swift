import SwiftUI
import AppKit

/// Snapshot of an NSScrollView's geometry at one instant.
struct ScrollMetrics: Equatable {
    var offset: CGFloat
    var contentHeight: CGFloat
    var viewportHeight: CGFloat
}

/// Observes the enclosing NSScrollView's clip-view bounds and forwards
/// the vertical scroll offset + content/viewport heights to SwiftUI.
/// SwiftUI ScrollView on macOS is backed by NSScrollView, but
/// PreferenceKey/GeometryReader-based scroll tracking is flaky inside
/// LazyVStack — going through AppKit avoids that.
struct ScrollOffsetReader: NSViewRepresentable {
    let onChange: (ScrollMetrics) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    typealias Callback = (ScrollMetrics) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingView)?.coordinator = context.coordinator
        context.coordinator.onChange = onChange
    }

    final class Coordinator: NSObject {
        var onChange: Callback
        weak var observedClip: NSClipView?

        init(onChange: @escaping Callback) {
            self.onChange = onChange
        }

        deinit {
            if let observedClip {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClip
                )
            }
        }

        @objc func boundsDidChange(_ note: Notification) {
            guard let clip = note.object as? NSClipView else { return }
            emit(from: clip)
        }

        func emit(from clip: NSClipView) {
            onChange(ScrollMetrics(
                offset: clip.bounds.origin.y,
                contentHeight: clip.documentView?.frame.size.height ?? 0,
                viewportHeight: clip.bounds.size.height
            ))
        }
    }

    final class TrackingView: NSView {
        var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            attach()
        }

        private func attach() {
            guard let coordinator else { return }
            // Walk up the AppKit hierarchy to find the NSScrollView.
            var v: NSView? = superview
            while v != nil, !(v is NSScrollView) {
                v = v?.superview
            }
            guard let scrollView = v as? NSScrollView else { return }
            let clip = scrollView.contentView
            if coordinator.observedClip === clip { return }
            if let previous = coordinator.observedClip {
                NotificationCenter.default.removeObserver(
                    coordinator,
                    name: NSView.boundsDidChangeNotification,
                    object: previous
                )
            }
            clip.postsBoundsChangedNotifications = true
            coordinator.observedClip = clip
            NotificationCenter.default.addObserver(
                coordinator,
                selector: #selector(Coordinator.boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clip
            )
            // Emit initial value.
            coordinator.emit(from: clip)
        }
    }
}
