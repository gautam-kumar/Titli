import XCTest
@testable import TitliCore

final class BrainTests: XCTestCase {
    let now = Brain.calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!

    func mem(_ s: String) -> Memory {
        guard case .memory(let m) = Brain.understand(s, now: now) else { XCTFail("not a memory: \(s)"); return Memory(raw: s) }
        return m
    }
    func ask(_ s: String, _ mems: [Memory]) -> Answer {
        guard case .question(let q) = Brain.understand(s, now: now) else { XCTFail("not a question: \(s)"); return Answer(kind: .none, say: "") }
        return Brain.answer(q, mems)
    }

    func testTranslit() {
        XCTAssertEqual(Brain.translit("दो हज़ार"), "do hazaar")
        XCTAssertEqual(Brain.loose("रमेश भैया"), "ramesh bhaiya")
    }

    func testGiveWithFestival() {
        for s in ["Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge", "मैंने रमेश भैया को दो हज़ार दिए, दिवाली तक लौटाएंगे"] {
            let m = mem(s)
            XCTAssertEqual(m.kind, .give, s)
            XCTAssertEqual(m.amount, 2000, s)
            XCTAssertEqual(m.person, "Ramesh bhaiya", s)
            XCTAssertEqual(m.due, "Diwali", s)
        }
    }

    func testTakeAndAmounts() {
        let m = mem("Imran se 1200 liye")
        XCTAssertEqual(m.kind, .take); XCTAssertEqual(m.amount, 1200); XCTAssertEqual(m.person, "Imran")
        let p = mem("Mujhe Pinky ko dhai hazaar dene hain")
        XCTAssertEqual(p.kind, .take); XCTAssertEqual(p.amount, 2500); XCTAssertEqual(p.person, "Pinky")
        let f = mem("Maine Ramesh bhaiya ko 1500 diye bacche ki fees ke liye")
        XCTAssertEqual(f.kind, .give); XCTAssertEqual(f.why, "bacche ki fees")
        XCTAssertEqual(Brain.parseAmount("sadhe tin hajar"), 3500)
        XCTAssertEqual(Brain.parseAmount("1.5 lakh"), 150000)
    }

    func testDocAndPlace() {
        for s in ["Aadhaar card almari ke drawer mein rakha hai", "आधार कार्ड अलमारी के ड्रॉअर में रखा है"] {
            let m = mem(s)
            XCTAssertEqual(m.kind, .doc, s); XCTAssertEqual(m.doc, "Aadhaar card", s)
            XCTAssertNotNil(m.place, s)
        }
        XCTAssertEqual(mem("Aadhaar card almari ke drawer mein rakha hai").place, "Almari ke drawer")
    }

    func testReminder() {
        let m = mem("Kal 10 baje gas cylinder book karna yaad dilana")
        XCTAssertEqual(m.kind, .remind); XCTAssertEqual(m.when, "Kal"); XCTAssertEqual(m.time, "10:00")
        XCTAssertEqual(m.sub, "Kal · 10:00")
    }

    func testAnswers() {
        let mems = ["Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge", "Maine Ramesh bhaiya ko 1500 diye bacche ki fees ke liye", "Imran se 1200 liye",
                    "Aadhaar card almari ke drawer mein rakha hai", "Kal 10 baje gas cylinder book karna yaad dilana"].map(mem)
        let a = ask("Ramesh ko kitna diya tha?", mems)
        XCTAssertEqual(a.kind, .money); XCTAssertEqual(a.net, 3500)
        XCTAssertEqual(a.say, "Ramesh bhaiya se 3,500 rupaye lene baaki hain.")
        XCTAssertEqual(ask("Imran ko kitne dene hain?", mems).net, -1200)
        let d = ask("आधार कार्ड कहाँ रखा है?", mems)
        XCTAssertEqual(d.kind, .doc); XCTAssertEqual(d.say, "Aadhaar card almari ke drawer mein rakha hai.")
        XCTAssertEqual(ask("Gas kab book karna hai?", mems).kind, .when)
        XCTAssertEqual(ask("Passport kahan hai?", []).kind, .none)
    }
}
