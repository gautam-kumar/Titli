import XCTest
@testable import TitliCore

final class AttachTests: XCTestCase {
    let now = Brain.calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
    let photo = Attachment(file: "a.jpg", kind: .image, name: "Photo")

    func testLabelBecomesDocOnPhone() {
        let m = Brain.attach(photo, to: Brain.understand("Ramesh ka bijli bill", now: now), now: now)
        XCTAssertEqual(m.kind, .doc); XCTAssertEqual(m.doc, "Ramesh ka bijli bill"); XCTAssertEqual(m.sub, "Phone")
        XCTAssertEqual(m.attachment, photo)
        XCTAssertEqual(Brain.docSay(m), "Ramesh ka bijli bill phone mein rakha hai.")
    }

    func testPhotoWordsAreTrimmed() {
        let m = Brain.attach(photo, to: Brain.understand("yeh dawai ki parchi ki photo hai", now: now), now: now)
        XCTAssertEqual(m.doc, "Dawai ki parchi")
    }

    func testKnownDocAndMoneyKeepTheirMeaning() {
        let d = Brain.attach(photo, to: Brain.understand("Aadhaar card ki photo", now: now), now: now)
        XCTAssertEqual(d.kind, .doc); XCTAssertEqual(d.doc, "Aadhaar card"); XCTAssertEqual(d.place, "Phone")
        let g = Brain.attach(photo, to: Brain.understand("Ramesh ko 2000 diye, yeh rasid hai", now: now), now: now)
        XCTAssertEqual(g.kind, .give); XCTAssertEqual(g.amount, 2000); XCTAssertNotNil(g.attachment)
    }

    func testFindsTheRightAttachedDoc() {
        let a = Brain.attach(photo, to: Brain.understand("Ramesh ka bijli bill", now: now), now: now)
        let b = Brain.attach(photo, to: Brain.understand("Dawai ki parchi", now: now), now: now)
        guard case .question(let q) = Brain.understand("parchi kahan hai?", now: now) else { return XCTFail() }
        XCTAssertEqual(Brain.answer(q, [a, b]).focus?.doc, "Dawai ki parchi")
    }

    func testOldSavedMemoriesStillLoad() throws {
        let old = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","raw":"x","created":0,"kind":"note","title":"x","sub":"y"}]"#
        let ms = try JSONDecoder().decode([Memory].self, from: Data(old.utf8))
        XCTAssertNil(ms[0].attachment)
    }
}
