import XCTest
@testable import Drawl

final class ScreenContextServiceTests: XCTestCase {
    let service = ScreenContextService()

    func testProperNounsAreKept() {
        let result = service.filterWords(from: "Hello Joop how are you today LinkedIn")
        XCTAssertTrue(result.contains("Joop"), "Expected proper noun 'Joop' in: \(result)")
        XCTAssertTrue(result.contains("LinkedIn"), "Expected 'LinkedIn' in: \(result)")
    }

    func testCommonWordsAreFiltered() {
        let result = service.filterWords(from: "the a of in to it")
        XCTAssertFalse(result.contains("the"))
        XCTAssertFalse(result.contains("of"))
    }

    func testCamelCaseIdentifiersAreKept() {
        let result = service.filterWords(from: "call transcribeAndInsert with audioSamples")
        XCTAssertTrue(result.contains("transcribeAndInsert"), "Expected camelCase in: \(result)")
        XCTAssertTrue(result.contains("audioSamples"), "Expected 'audioSamples' in: \(result)")
    }

    func testPascalCaseKept() {
        let result = service.filterWords(from: "WhisperEngine ScreenContextService DecodingOptions")
        XCTAssertTrue(result.contains("WhisperEngine"))
        XCTAssertTrue(result.contains("ScreenContextService"))
        XCTAssertTrue(result.contains("DecodingOptions"))
    }

    func testAbbreviationsKept() {
        let result = service.filterWords(from: "Using the API in OCR with NLP")
        XCTAssertTrue(result.contains("API"))
        XCTAssertTrue(result.contains("OCR"))
        XCTAssertTrue(result.contains("NLP"))
    }

    func testDeduplication() {
        let result = service.filterWords(from: "Joop Joop Joop LinkedIn LinkedIn")
        let words = result.components(separatedBy: " ")
        XCTAssertEqual(words.filter { $0 == "Joop" }.count, 1)
        XCTAssertEqual(words.filter { $0 == "LinkedIn" }.count, 1)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(service.filterWords(from: ""), "")
    }

    func testResultCappedAt150Words() {
        var words: [String] = []
        let bases = ["Aardvark", "Basilisk", "Chimera", "Dragon", "Elephant", "Falcon", "Gorilla", "Heron", "Iguana", "Jaguar"]
        for i in 0..<200 {
            words.append(bases[i % bases.count])
        }
        let result = service.filterWords(from: words.joined(separator: " "))
        let count = result.components(separatedBy: " ").filter { !$0.isEmpty }.count
        XCTAssertLessThanOrEqual(count, 150)
    }

    func testOCRNoiseIsRejected() {
        let result = service.filterWords(from: "Mes5agin9 Rt$pon5iblo Be$t comlnotifie8tionsPfilter Joop Roberts")
        XCTAssertFalse(result.contains("Mes5agin9"))
        XCTAssertFalse(result.contains("Rt$pon5iblo"))
        XCTAssertFalse(result.contains("Be$t"))
        XCTAssertFalse(result.contains("comlnotifie8tionsPfilter"))
        XCTAssertTrue(result.contains("Joop"))
        XCTAssertTrue(result.contains("Roberts"))
    }
}
