import XCTest
@testable import SenseLayer

final class DraftStoreTests: XCTestCase {

    // MARK: - Save and load

    func testSaveAndLoadDraft() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "Alice", text: "Hey there")
        XCTAssertEqual(store.loadDraft(conversationKey: "Alice"), "Hey there")
    }

    func testLoadReturnsNilWhenNoDraft() {
        let store = DraftStore()
        XCTAssertNil(store.loadDraft(conversationKey: "Nobody"))
    }

    func testSaveOverwritesPreviousDraft() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "Bob", text: "First")
        store.saveDraft(conversationKey: "Bob", text: "Second")
        XCTAssertEqual(store.loadDraft(conversationKey: "Bob"), "Second")
    }

    // MARK: - Clear

    func testClearRemovesDraft() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "Carol", text: "Draft text")
        store.clearDraft(conversationKey: "Carol")
        XCTAssertNil(store.loadDraft(conversationKey: "Carol"))
    }

    func testClearOnNonexistentKeyIsNoOp() {
        var store = DraftStore()
        store.clearDraft(conversationKey: "Ghost")
        XCTAssertNil(store.loadDraft(conversationKey: "Ghost"))
    }

    // MARK: - Isolation between keys

    func testDraftsAreIsolatedByKey() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "A", text: "Alpha")
        store.saveDraft(conversationKey: "B", text: "Beta")
        XCTAssertEqual(store.loadDraft(conversationKey: "A"), "Alpha")
        XCTAssertEqual(store.loadDraft(conversationKey: "B"), "Beta")
    }

    func testClearOnlyAffectsTargetKey() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "X", text: "Keep")
        store.saveDraft(conversationKey: "Y", text: "Remove")
        store.clearDraft(conversationKey: "Y")
        XCTAssertEqual(store.loadDraft(conversationKey: "X"), "Keep")
        XCTAssertNil(store.loadDraft(conversationKey: "Y"))
    }

    // MARK: - Empty string

    func testSaveEmptyStringIsValid() {
        var store = DraftStore()
        store.saveDraft(conversationKey: "E", text: "")
        XCTAssertEqual(store.loadDraft(conversationKey: "E"), "")
    }
}
