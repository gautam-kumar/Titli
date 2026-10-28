import XCTest
@testable import TitliCore

final class AITests: XCTestCase {
    let now = Brain.calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!

    func mems() -> [Memory] {
        ["Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge", "Maine Ramesh bhaiya ko 1500 diye bacche ki fees ke liye", "Imran se 1200 liye",
         "Aadhaar card almari ke drawer mein rakha hai", "Kal 10 baje gas cylinder book karna yaad dilana"].compactMap {
            if case .memory(let m) = Brain.understand($0, now: now) { return m } else { return nil }
        }
    }

    func testSaveMoney() {
        let r = AIReply(intent: "save", kind: "give", amount: 2000, person: "Ramesh bhaiya", due: "Diwali", dueDate: "2026-11-08")
        guard case .memory(let m) = AI.interpret(r, said: "रमेश भैया को दो हज़ार दिए", memories: [], now: now) else { return XCTFail() }
        XCTAssertEqual(m.kind, .give); XCTAssertEqual(m.amount, 2000); XCTAssertEqual(m.title, "Ramesh bhaiya ko ₹2,000")
        XCTAssertEqual(m.due, "Diwali"); XCTAssertNotNil(m.dueDate)
    }

    func testMoneyWithoutAmountBecomesNote() {
        guard case .memory(let m) = AI.interpret(AIReply(intent: "save", kind: "give", person: "Ramesh"), said: "Ramesh ko paise diye", memories: [], now: now) else { return XCTFail() }
        XCTAssertEqual(m.kind, .note)
    }

    func testSaveDocAndReminder() {
        guard case .memory(let d) = AI.interpret(AIReply(intent: "save", kind: "doc", doc: "PAN card", place: "neeli file"), said: "PAN card neeli file mein hai", memories: [], now: now) else { return XCTFail() }
        XCTAssertEqual(d.title, "PAN card"); XCTAssertEqual(d.sub, "Neeli file")
        guard case .memory(let r) = AI.interpret(AIReply(intent: "save", kind: "remind", due: "Kal", time: "10:00", what: "Bijli bill bharna"), said: "kal 10 baje bijli bill", memories: [], now: now) else { return XCTFail() }
        XCTAssertEqual(r.title, "Bijli bill bharna"); XCTAssertEqual(r.sub, "Kal · 10:00")
    }

    func testMoneyTotalsAreComputedOnPhone() {
        // the model's own sentence and numbers are ignored for money; totals come from the memories
        let r = AIReply(intent: "ask", person: "Ramesh", answerKind: "money", matches: [0], say: "Ramesh se 99 rupaye")
        guard case .answer(let a) = AI.interpret(r, said: "Ramesh ko kitna diya?", memories: mems(), now: now) else { return XCTFail() }
        XCTAssertEqual(a.net, 3500); XCTAssertEqual(a.entries.count, 2)
        XCTAssertEqual(a.say, "Ramesh bhaiya se 3,500 rupaye lene baaki hain.")
    }

    func testDocAnswerAndBadIndexes() {
        let r = AIReply(intent: "ask", answerKind: "doc", matches: [42, 3])
        guard case .answer(let a) = AI.interpret(r, said: "Aadhaar kahan hai?", memories: mems(), now: now) else { return XCTFail() }
        XCTAssertEqual(a.kind, .doc); XCTAssertEqual(a.say, "Aadhaar card almari ke drawer mein rakha hai.")
        XCTAssertNil(AI.interpret(AIReply(intent: "ask", answerKind: "when", matches: [99]), said: "kab?", memories: mems(), now: now))
    }

    func testDecodeAndRequest() {
        XCTAssertEqual(AI.decode("```json\n{\"intent\":\"ask\",\"answerKind\":\"none\"}\n```")?.answerKind, "none")
        XCTAssertNil(AI.decode("not json"))
        let req = AI.request(said: "Imran?", memories: mems())
        XCTAssertTrue(req.contains("\"said\":\"Imran?\"")); XCTAssertTrue(req.contains("\"n\":2"))
        XCTAssertTrue(AI.instructions(now: now).contains("2026-10-28 Wednesday"))
    }
}
