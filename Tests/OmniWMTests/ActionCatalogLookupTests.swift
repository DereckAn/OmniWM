// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

@testable import OmniWM
import XCTest

final class ActionCatalogLookupTests: XCTestCase {
    func testCommandLookupPreservesCatalogMetadata() {
        let specs = ActionCatalog.allSpecs()
        for spec in specs {
            let expected = specs.first { $0.command == spec.command }
            XCTAssertEqual(ActionCatalog.spec(for: spec.command), expected, spec.id)
            XCTAssertEqual(spec.command.displayName, expected?.title, spec.id)
            XCTAssertEqual(spec.command.layoutCompatibility, expected?.layoutCompatibility, spec.id)
        }
    }

    func testUncataloguedCommandsKeepDisplayFallbacks() {
        let commands: [HotkeyCommand] = [
            .workspace(.switchTo(9999)),
            .column(.moveToIndex(123)),
            .sizing(.setContainerPrimarySpan(.setFixed(3.14159)))
        ]
        for command in commands {
            XCTAssertNil(ActionCatalog.spec(for: command))
            XCTAssertEqual(command.displayName, String(describing: command))
            XCTAssertEqual(command.layoutCompatibility, .shared)
        }
    }

    func testNormalizedSearchMetadataIncludesIDsScopesKeywordsAndIPCWords() throws {
        let terms = try XCTUnwrap(ActionCatalog.normalizedSearchTerms(for: "moveWindowToMonitor.left"))

        for expected in [
            "movewindowtomonitor left",
            "move window to left monitor",
            "shared",
            "adjacent monitor",
            "send window",
            "command move to monitor <left|right|up|down>",
            "move to monitor"
        ] {
            XCTAssertTrue(terms.contains(expected), expected)
        }
        XCTAssertEqual(Set(terms).count, terms.count)
        XCTAssertNil(ActionCatalog.normalizedSearchTerms(for: "unknown-action"))
    }
}
