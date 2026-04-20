import XCTest
@testable import Curator

/// Tests for PhotoPredicate, DateRange, and FileFormatFilter models.
///
/// Verifies:
/// - PhotoPredicate.all has nil dateRange and .all fileFormat
/// - PhotoPredicate.dateRange(from:to:) creates correct date range
/// - PhotoPredicate.filter(fileFormat:) creates correct format filter
/// - DateRange equality
/// - FileFormatFilter raw values
final class PhotoPredicateTests: XCTestCase {

    // MARK: - PhotoPredicate.all

    /// [P0] PhotoPredicate.all has nil dateRange
    func testAllPredicateHasNilDateRange() {
        let predicate = PhotoPredicate.all
        XCTAssertNil(predicate.dateRange,
            "PhotoPredicate.all should have nil dateRange")
    }

    /// [P0] PhotoPredicate.all has .all fileFormat
    func testAllPredicateHasAllFileFormat() {
        let predicate = PhotoPredicate.all
        XCTAssertEqual(predicate.fileFormat, .all,
            "PhotoPredicate.all should have .all fileFormat")
    }

    /// [P0] PhotoPredicate.all has empty rawValue
    func testAllPredicateHasEmptyRawValue() {
        let predicate = PhotoPredicate.all
        XCTAssertTrue(predicate.rawValue.isEmpty,
            "PhotoPredicate.all should have empty rawValue")
    }

    // MARK: - PhotoPredicate.dateRange(from:to:)

    /// [P0] PhotoPredicate.dateRange creates a predicate with correct date range
    func testDateRangePredicateCreatesCorrectDateRange() {
        let fromDate = Date(timeIntervalSince1970: 1_700_000_000)
        let toDate = Date(timeIntervalSince1970: 1_700_100_000)

        let predicate = PhotoPredicate.dateRange(from: fromDate, to: toDate)

        XCTAssertNotNil(predicate.dateRange,
            "dateRange predicate should have non-nil dateRange")
        XCTAssertEqual(predicate.dateRange?.from, fromDate,
            "dateRange from value should match input")
        XCTAssertEqual(predicate.dateRange?.to, toDate,
            "dateRange to value should match input")
    }

    /// [P1] PhotoPredicate.dateRange has .all fileFormat
    func testDateRangePredicateHasAllFileFormat() {
        let fromDate = Date(timeIntervalSince1970: 1_700_000_000)
        let toDate = Date(timeIntervalSince1970: 1_700_100_000)

        let predicate = PhotoPredicate.dateRange(from: fromDate, to: toDate)

        XCTAssertEqual(predicate.fileFormat, .all,
            "dateRange predicate should default to .all fileFormat")
    }

    /// [P1] PhotoPredicate.dateRange rawValue encodes the timestamps
    func testDateRangePredicateRawValueContainsTimestamps() {
        let fromDate = Date(timeIntervalSince1970: 1_700_000_000)
        let toDate = Date(timeIntervalSince1970: 1_700_100_000)

        let predicate = PhotoPredicate.dateRange(from: fromDate, to: toDate)

        XCTAssertTrue(predicate.rawValue.hasPrefix("dateRange:"),
            "dateRange predicate rawValue should start with 'dateRange:'")
        XCTAssertTrue(predicate.rawValue.contains("\(fromDate.timeIntervalSince1970)"),
            "rawValue should contain the from timestamp")
    }

    // MARK: - PhotoPredicate.filter(fileFormat:)

    /// [P0] PhotoPredicate.filter creates correct format filter for .images
    func testFilterPredicateCreatesImagesFormat() {
        let predicate = PhotoPredicate.filter(fileFormat: .images)
        XCTAssertEqual(predicate.fileFormat, .images,
            "filter predicate should have .images fileFormat")
    }

    /// [P0] PhotoPredicate.filter creates correct format filter for .heic
    func testFilterPredicateCreatesHeicFormat() {
        let predicate = PhotoPredicate.filter(fileFormat: .heic)
        XCTAssertEqual(predicate.fileFormat, .heic,
            "filter predicate should have .heic fileFormat")
    }

    /// [P0] PhotoPredicate.filter creates correct format filter for .raw
    func testFilterPredicateCreatesRawFormat() {
        let predicate = PhotoPredicate.filter(fileFormat: .raw)
        XCTAssertEqual(predicate.fileFormat, .raw,
            "filter predicate should have .raw fileFormat")
    }

    /// [P1] PhotoPredicate.filter has nil dateRange
    func testFilterPredicateHasNilDateRange() {
        let predicate = PhotoPredicate.filter(fileFormat: .images)
        XCTAssertNil(predicate.dateRange,
            "filter predicate should have nil dateRange")
    }

    /// [P1] PhotoPredicate.filter rawValue encodes the format
    func testFilterPredicateRawValueContainsFormat() {
        let predicate = PhotoPredicate.filter(fileFormat: .heic)
        XCTAssertTrue(predicate.rawValue.hasPrefix("fileFormat:"),
            "filter predicate rawValue should start with 'fileFormat:'")
        XCTAssertTrue(predicate.rawValue.contains("heic"),
            "rawValue should contain the format name")
    }

    // MARK: - PhotoPredicate Equatable

    /// [P1] PhotoPredicate conforms to Equatable — same predicates are equal
    func testPhotoPredicateEquatableSameValues() {
        let p1 = PhotoPredicate.all
        let p2 = PhotoPredicate.all
        XCTAssertEqual(p1, p2,
            "Two .all predicates should be equal")
    }

    /// [P1] PhotoPredicate conforms to Equatable — different predicates are not equal
    func testPhotoPredicateEquatableDifferentValues() {
        let allPredicate = PhotoPredicate.all
        let heicPredicate = PhotoPredicate.filter(fileFormat: .heic)
        XCTAssertNotEqual(allPredicate, heicPredicate,
            ".all and .heic filter predicates should not be equal")
    }

    // MARK: - DateRange

    /// [P0] DateRange equality works for same values
    func testDateRangeEqualitySameValues() {
        let range1 = DateRange(from: Date(timeIntervalSince1970: 100), to: Date(timeIntervalSince1970: 200))
        let range2 = DateRange(from: Date(timeIntervalSince1970: 100), to: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(range1, range2,
            "DateRanges with same from/to should be equal")
    }

    /// [P0] DateRange inequality works for different values
    func testDateRangeInequalityDifferentValues() {
        let range1 = DateRange(from: Date(timeIntervalSince1970: 100), to: Date(timeIntervalSince1970: 200))
        let range2 = DateRange(from: Date(timeIntervalSince1970: 100), to: Date(timeIntervalSince1970: 300))
        XCTAssertNotEqual(range1, range2,
            "DateRanges with different 'to' values should not be equal")
    }

    /// [P1] DateRange stores correct from and to values
    func testDateRangeStoresFromAndTo() {
        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let to = Date(timeIntervalSince1970: 1_700_100_000)
        let range = DateRange(from: from, to: to)

        XCTAssertEqual(range.from, from)
        XCTAssertEqual(range.to, to)
    }

    // MARK: - FileFormatFilter

    /// [P0] FileFormatFilter raw values match expected strings
    func testFileFormatFilterRawValues() {
        XCTAssertEqual(FileFormatFilter.all.rawValue, "all")
        XCTAssertEqual(FileFormatFilter.images.rawValue, "images")
        XCTAssertEqual(FileFormatFilter.heic.rawValue, "heic")
        XCTAssertEqual(FileFormatFilter.raw.rawValue, "raw")
    }

    /// [P1] FileFormatFilter Equatable conformance
    func testFileFormatFilterEquatable() {
        XCTAssertEqual(FileFormatFilter.all, FileFormatFilter.all)
        XCTAssertNotEqual(FileFormatFilter.all, FileFormatFilter.images)
        XCTAssertNotEqual(FileFormatFilter.heic, FileFormatFilter.raw)
    }
}
