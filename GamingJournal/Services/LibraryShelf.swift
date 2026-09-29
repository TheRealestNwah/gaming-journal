import Foundation

/// How the Library's shelf is filtered and ordered. Pinned notebooks always come first.
struct LibraryShelf: Equatable {
    enum Filter: String, CaseIterable, Identifiable {
        case all, ongoing, completed, abandoned

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "All tales"
            case .ongoing: NotebookStatus.ongoing.label
            case .completed: NotebookStatus.completed.label
            case .abandoned: NotebookStatus.abandoned.label
            }
        }

        var status: NotebookStatus? {
            switch self {
            case .all: nil
            case .ongoing: .ongoing
            case .completed: .completed
            case .abandoned: .abandoned
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case lastWritten, started, title

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lastWritten: "Last written"
            case .started: "Date begun"
            case .title: "Title"
            }
        }
    }

    static let filterKey = "library.filter"
    static let sortKey = "library.sort"

    var filter = Filter.all
    var sort = Sort.lastWritten

    func arrange(_ notebooks: [Notebook]) -> [Notebook] {
        notebooks
            .filter { notebook in filter.status.map { notebook.status == $0 } ?? true }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                switch sort {
                case .lastWritten:
                    return lhs.updatedAt > rhs.updatedAt
                case .started:
                    return lhs.startedAt > rhs.startedAt
                case .title:
                    let order = lhs.title.localizedStandardCompare(rhs.title)
                    return order == .orderedSame ? lhs.createdAt < rhs.createdAt : order == .orderedAscending
                }
            }
    }
}
