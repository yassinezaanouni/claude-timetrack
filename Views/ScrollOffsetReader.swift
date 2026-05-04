import SwiftUI
import AppKit

/// Observes the enclosing NSScrollView's clip-view bounds and forwards
/// the vertical scroll offset to SwiftUI. SwiftUI ScrollView on macOS is
/// backed by NSScrollView, but PreferenceKey/GeometryReader-based scroll
/// tracking is flaky inside LazyVStack — going through AppKit avoids that.
struct ScrollOffsetReader: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

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
        var onChange: (CGFloat) -> Void
        weak var observedClip: NSClipView?

        init(onChange: @escaping (CGFloat) -> Void) {
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
            onChange(clip.bounds.origin.y)
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
            coordinator.onChange(clip.bounds.origin.y)
        }
    }
}
