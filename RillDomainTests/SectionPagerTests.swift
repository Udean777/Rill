import Testing

@testable import RillDomain

@Suite("SectionPager")
struct SectionPagerTests {
    @Test func `page count rounds up`() {
        #expect(SectionPager.pageCount(itemCount: 0, pageSize: 5) == 0)
        #expect(SectionPager.pageCount(itemCount: 1, pageSize: 5) == 1)
        #expect(SectionPager.pageCount(itemCount: 5, pageSize: 5) == 1)
        #expect(SectionPager.pageCount(itemCount: 6, pageSize: 5) == 2)
        #expect(SectionPager.pageCount(itemCount: 51, pageSize: 5) == 11)
    }

    @Test func `page count is zero for a non-positive page size`() {
        #expect(SectionPager.pageCount(itemCount: 10, pageSize: 0) == 0)
        #expect(SectionPager.pageCount(itemCount: 10, pageSize: -1) == 0)
    }

    @Test func `clamp keeps the page inside the range`() {
        #expect(SectionPager.clamp(page: -3, itemCount: 12, pageSize: 5) == 0)
        #expect(SectionPager.clamp(page: 1, itemCount: 12, pageSize: 5) == 1)
        #expect(SectionPager.clamp(page: 99, itemCount: 12, pageSize: 5) == 2)
        #expect(SectionPager.clamp(page: 4, itemCount: 0, pageSize: 5) == 0)
    }

    @Test func `slice returns one window and pads the last page`() {
        let items = Array(0..<12)

        #expect(Array(SectionPager.slice(items, page: 0, pageSize: 5)) == [0, 1, 2, 3, 4])
        #expect(Array(SectionPager.slice(items, page: 2, pageSize: 5)) == [10, 11])
        #expect(Array(SectionPager.slice(items, page: 99, pageSize: 5)) == [10, 11])
        #expect(SectionPager.slice(items, page: 0, pageSize: 5).isEmpty == false)
    }

    @Test func `slice is empty for no items or a non-positive page size`() {
        let items = Array(0..<3)

        #expect(SectionPager.slice([Int](), page: 0, pageSize: 5).isEmpty)
        #expect(SectionPager.slice(items, page: 0, pageSize: 0).isEmpty)
    }
}
