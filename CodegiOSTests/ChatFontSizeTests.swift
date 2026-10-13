import SwiftUI
import UIKit
import XCTest
@testable import Codeg

final class ChatFontSizeTests: XCTestCase {
    func testBodyRampBottomsAtXSmall14() {
        XCTAssertEqual(ChatFontSize.bodyPointSize(.large), 17, accuracy: 0.01)
        XCTAssertEqual(ChatFontSize.bodyPointSize(.medium), 16, accuracy: 0.01)
        XCTAssertEqual(ChatFontSize.bodyPointSize(.small), 15, accuracy: 0.01)
        XCTAssertEqual(ChatFontSize.bodyPointSize(.xSmall), 14, accuracy: 0.01)
        // No Dynamic Type step below .xSmall, so nothing in the ramp is ~13pt.
        XCTAssertEqual(DynamicTypeSize.allCases.first, .xSmall)
        XCTAssertGreaterThan(ChatFontSize.bodyPointSize(.xSmall), ChatFontSize.extraSmallBodyTarget)
    }

    func testDefaultLadderIs17_15_13() {
        let normal = ChatFontSize.normal.resolution(from: .large)
        let small = ChatFontSize.small.resolution(from: .large)
        let extraSmall = ChatFontSize.extraSmall.resolution(from: .large)

        XCTAssertEqual(normal.dynamicType, .large)
        XCTAssertEqual(normal.bodyScale, 1, accuracy: 0.0001)
        XCTAssertFalse(normal.appliesFloorScale)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(normal), 17, accuracy: 0.05)

        XCTAssertEqual(small.dynamicType, .small)
        XCTAssertEqual(small.bodyScale, 1, accuracy: 0.0001)
        XCTAssertFalse(small.appliesFloorScale)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(small), 15, accuracy: 0.05)

        XCTAssertEqual(extraSmall.dynamicType, .xSmall)
        XCTAssertTrue(extraSmall.appliesFloorScale)
        XCTAssertEqual(extraSmall.bodyScale, 13.0 / 14.0, accuracy: 0.0001)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(extraSmall), 13, accuracy: 0.05)
    }

    func testStepsMatchTheSharedLadder() {
        XCTAssertEqual(ChatFontSize.normal.steps, 0)
        XCTAssertEqual(ChatFontSize.small.steps, 2)
        XCTAssertEqual(ChatFontSize.extraSmall.steps, 3)
    }

    func testChatNormalKeepsTheAppFloor() {
        let app = ChatFontSize.extraSmall.resolution(from: .large)
        let chat = ChatFontSize.normal.resolution(from: app.dynamicType, inheritedFloorScale: app.bodyScale)
        XCTAssertEqual(chat.dynamicType, .xSmall)
        XCTAssertFalse(chat.appliesFloorScale)
        XCTAssertEqual(chat.bodyScale, app.bodyScale, accuracy: 0.0001)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(chat), 13, accuracy: 0.05)
    }

    func testFloorScaleDoesNotCompoundWhenChatStacksOnApp() {
        let app = ChatFontSize.extraSmall.resolution(from: .large)
        let chat = ChatFontSize.extraSmall.resolution(
            from: app.dynamicType,
            inheritedFloorScale: app.bodyScale
        )
        XCTAssertEqual(chat.dynamicType, .xSmall)
        XCTAssertFalse(chat.appliesFloorScale)
        XCTAssertEqual(chat.bodyScale, app.bodyScale, accuracy: 0.0001)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(chat), 13, accuracy: 0.05)
    }

    func testChatExtraSmallOnAppSmallReaches13() {
        let app = ChatFontSize.small.resolution(from: .large)
        XCTAssertEqual(app.dynamicType, .small)
        XCTAssertFalse(app.appliesFloorScale)

        let chat = ChatFontSize.extraSmall.resolution(
            from: app.dynamicType,
            inheritedFloorScale: app.bodyScale
        )
        XCTAssertEqual(chat.dynamicType, .xSmall)
        XCTAssertTrue(chat.appliesFloorScale)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(chat), 13, accuracy: 0.05)
    }

    func testSmallClampedAtXSmallDoesNotUseTheFloorScale() {
        // System .small is already one step above the floor; 小 steps two and clamps.
        let resolved = ChatFontSize.small.resolution(from: .small)
        XCTAssertEqual(resolved.dynamicType, .xSmall)
        XCTAssertFalse(resolved.appliesFloorScale)
        XCTAssertEqual(resolved.bodyScale, 1, accuracy: 0.0001)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(resolved), 14, accuracy: 0.05)
    }

    func testExtraSmallAboveTheFloorDoesNotScale() {
        // .xLarge − 3 = .small (15pt). Still a real Dynamic Type step, so no 13/14 scale.
        let resolved = ChatFontSize.extraSmall.resolution(from: .xLarge)
        XCTAssertEqual(resolved.dynamicType, .small)
        XCTAssertFalse(resolved.appliesFloorScale)
        XCTAssertEqual(ChatFontSize.renderedBodyPointSize(resolved), 15, accuracy: 0.05)
    }

    func testAccessibilitySizeOnlyStepsThreeTimes() throws {
        let resolved = ChatFontSize.extraSmall.resolution(from: .accessibility1)
        let all = Array(DynamicTypeSize.allCases)
        let base = try XCTUnwrap(all.firstIndex(of: .accessibility1))
        XCTAssertEqual(resolved.dynamicType, all[base - 3])
        XCTAssertGreaterThan(resolved.dynamicType, .xSmall)
        XCTAssertFalse(resolved.appliesFloorScale)
        XCTAssertEqual(resolved.bodyScale, 1, accuracy: 0.0001)
    }
}
