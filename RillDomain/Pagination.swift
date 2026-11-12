/// Pagination math for a section that shows a fixed window of rows per page.
/// Pure, so the palette only carries the page index.
public enum SectionPager {
    /// Number of pages needed to show `itemCount` items, or `0` when empty.
    public static func pageCount(itemCount: Int, pageSize: Int) -> Int {
        guard itemCount > 0, pageSize > 0 else { return 0 }
        return (itemCount + pageSize - 1) / pageSize
    }

    /// `page` clamped into `0..<pageCount`; `0` when there are no pages.
    public static func clamp(page: Int, itemCount: Int, pageSize: Int) -> Int {
        let count = pageCount(itemCount: itemCount, pageSize: pageSize)
        guard count > 0 else { return 0 }
        return min(max(page, 0), count - 1)
    }

    /// The window of items on `page`, clamped; empty when there are none.
    public static func slice<T>(_ items: [T], page: Int, pageSize: Int) -> ArraySlice<T> {
        guard pageSize > 0 else { return items[items.startIndex..<items.startIndex] }
        let clampedPage = clamp(page: page, itemCount: items.count, pageSize: pageSize)
        let start = min(clampedPage * pageSize, items.count)
        let end = min(start + pageSize, items.count)
        return items[start..<end]
    }
}
