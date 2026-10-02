#if os(macOS)
import SwiftUI

struct BookPager: View {
    let spreadCount: Int
    @Binding var spread: Int
    let curls: Bool
    let content: (Int) -> AnyView

    var body: some View {
        content(min(max(0, spread), max(0, spreadCount - 1)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
