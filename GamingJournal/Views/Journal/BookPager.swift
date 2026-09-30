import SwiftUI
import UIKit

/// Turns a book's spreads (one page, or two facing pages) with a page curl, or with a plain slide
/// when `curls` is off (Reduce Motion). SwiftUI's paged TabView can't curl, so this wraps
/// `UIPageViewController`. The curl style is fixed when the controller is made, so give this view
/// an `.id` that changes with `curls`.
struct BookPager: UIViewControllerRepresentable {
    let spreadCount: Int
    /// The spread on show. Set by the reader to turn, and by the book when the reader swipes.
    @Binding var spread: Int
    let curls: Bool
    let content: (Int) -> AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: curls ? .pageCurl : .scroll,
            navigationOrientation: .horizontal,
            options: curls ? [.spineLocation: UIPageViewController.SpineLocation.min.rawValue] : nil
        )
        controller.isDoubleSided = false
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .clear
        controller.setViewControllers([context.coordinator.spreadController(spread)], direction: .forward, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let current = controller.viewControllers?.first as? SpreadController else { return }
        if current.index == spread {
            // Same spread, perhaps with new words on it.
            current.rootView = content(spread)
        } else if !coordinator.isTurning {
            controller.setViewControllers(
                [coordinator.spreadController(spread)],
                direction: spread > current.index ? .forward : .reverse,
                animated: context.transaction.animation != nil
            )
        }
    }

    /// Hosts one spread.
    final class SpreadController: UIHostingController<AnyView> {
        var index = 0
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: BookPager
        /// A swipe is under way; don't turn the book from under the reader's finger.
        var isTurning = false

        init(_ parent: BookPager) {
            self.parent = parent
        }

        func spreadController(_ index: Int) -> SpreadController {
            let controller = SpreadController(rootView: parent.content(index))
            controller.index = index
            controller.view.backgroundColor = .clear
            // The book already sits inside the safe area.
            controller.safeAreaRegions = []
            return controller
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? SpreadController)?.index, index > 0 else { return nil }
            return spreadController(index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? SpreadController)?.index, index + 1 < parent.spreadCount else { return nil }
            return spreadController(index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTurning = false
            if completed, let current = pageViewController.viewControllers?.first as? SpreadController {
                parent.spread = current.index
            }
        }
    }
}
