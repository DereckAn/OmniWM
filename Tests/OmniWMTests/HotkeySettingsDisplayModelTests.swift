// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import Carbon
@testable import OmniWM
import XCTest

final class HotkeySettingsDisplayModelTests: XCTestCase {
    func testAdvancedSearchMatchCountFindsReportedSizingCommands() {
        let ids = [
            "setContainerPrimarySpan.decrease10Percent",
            "setContainerPrimarySpan.increase10Percent",
            "setWindowSecondarySpan.decrease10Percent",
            "setWindowSecondarySpan.increase10Percent"
        ]
        let bindings = HotkeyBindingRegistry.defaults().filter { ids.contains($0.id) }

        XCTAssertEqual(hiddenAdvancedMatchCount("increase", bindings: bindings), 2)
        XCTAssertEqual(hiddenAdvancedMatchCount("decrease", bindings: bindings), 2)
    }

    func testAdvancedSearchMatchCountFindsMoveContainerCommandsByColumnID() {
        let ids = ["moveColumn.left", "moveColumn.right"]
        let bindings = HotkeyBindingRegistry.defaults().filter { ids.contains($0.id) }

        XCTAssertEqual(hiddenAdvancedMatchCount("column", bindings: bindings), 2)
    }

    func testAdvancedSearchMatchCountUsesConfiguredShortcut() throws {
        let shortcut = try XCTUnwrap(KeySymbolMapper.fromHumanReadable("Hyper+Minus"))
        let binding = try XCTUnwrap(HotkeyBindingRegistry.makeBinding(
            id: "setContainerPrimarySpan.decrease10Percent",
            binding: shortcut
        ))

        XCTAssertEqual(
            hiddenAdvancedMatchCount("hyper+minus", bindings: [binding]),
            1
        )
    }

    func testAdvancedSearchMatchCountExcludesNormalCommands() {
        let ids = ["move.left", "moveColumn.left"]
        let bindings = HotkeyBindingRegistry.defaults().filter { ids.contains($0.id) }

        XCTAssertEqual(bindings.count, ids.count)
        XCTAssertEqual(hiddenAdvancedMatchCount("left", bindings: bindings), 1)
    }

    func testAdvancedSearchMatchCountRequiresAQuery() {
        XCTAssertEqual(
            hiddenAdvancedMatchCount("  ", bindings: HotkeyBindingRegistry.defaults()),
            0
        )
    }

    func testVisibilityKeepsAdvancedCommandsBehindTheToggle() throws {
        let advanced = try XCTUnwrap(HotkeyBindingRegistry.makeBinding(id: "moveColumn.left", binding: .unassigned))
        let unavailable = HotkeyBinding(
            id: "consumeOrExpelWindowLeft",
            command: .focusNavigation(.previous),
            trigger: .unassigned
        )
        let bindings = [advanced, unavailable]
        let hidden = HotkeySettingsDisplayModel.search("", bindings: bindings, showsAdvancedHotkeys: false)
        let shown = HotkeySettingsDisplayModel.search("", bindings: bindings, showsAdvancedHotkeys: true)

        XCTAssertTrue(hidden.groups.isEmpty)
        XCTAssertEqual(hidden.hiddenAdvancedMatchCount, 0)
        XCTAssertEqual(shown.groups.flatMap(\.bindings).map(\.id), [advanced.id])
        XCTAssertEqual(shown.hiddenAdvancedMatchCount, 0)
    }

    func testSearchPreservesCategoryAndBindingOrderAndOmitsEmptyGroups() {
        let bindings = Array(HotkeyBindingRegistry.defaults().reversed())
        let results = HotkeySettingsDisplayModel.search("left", bindings: bindings, showsAdvancedHotkeys: true)
        let categories = results.groups.map(\.category)
        XCTAssertEqual(categories, HotkeyCategory.allCases.filter { categories.contains($0) })
        XCTAssertFalse(results.groups.isEmpty)
        for group in results.groups {
            XCTAssertFalse(group.bindings.isEmpty)
            XCTAssertTrue(group.bindings.allSatisfy { $0.category == group.category })
            let ids = Set(group.bindings.map(\.id))
            XCTAssertEqual(group.bindings.map(\.id), bindings.filter { ids.contains($0.id) }.map(\.id))
        }
    }

    func testSearchUpdatesImmediatelyAfterShortcutChanges() throws {
        let first = try XCTUnwrap(HotkeyBindingRegistry.makeBinding(
            id: "move.left",
            binding: KeyBinding(keyCode: UInt32(kVK_F18), modifiers: UInt32(optionKey)).settingSide(.right)
        ))
        let reset = try XCTUnwrap(HotkeyBindingRegistry.makeBinding(id: first.id, binding: .unassigned))
        XCTAssertEqual(searchIDs("F18", bindings: [first]), [first.id])
        XCTAssertEqual(searchIDs(first.binding.humanReadableString, bindings: [first]), [first.id])
        XCTAssertTrue(searchIDs("F18", bindings: [reset]).isEmpty)
        XCTAssertEqual(searchIDs("Unassigned", bindings: [reset]), [first.id])
    }

    func testSearchUsesCurrentHyperCompositionAfterMetadataIsCached() throws {
        let original = try XCTUnwrap(HyperKeyModifiers(carbonMask: KeySymbolMapper.hyperModifiers))
        defer { KeySymbolMapper.setHyperKeyModifiers(original) }
        KeySymbolMapper.setHyperKeyModifiers(.default)
        let binding = try XCTUnwrap(HotkeyBindingRegistry.makeBinding(
            id: "move.left",
            binding: KeyBinding(keyCode: UInt32(kVK_F18), modifiers: HyperKeyModifiers.default.carbonMask)
        ))
        XCTAssertEqual(searchIDs("Hyper+F18", bindings: [binding]), [binding.id])
        KeySymbolMapper
            .setHyperKeyModifiers(try XCTUnwrap(HyperKeyModifiers.fromHumanReadable("Control+Option+Command")))
        XCTAssertTrue(searchIDs("Hyper+F18", bindings: [binding]).isEmpty)
        XCTAssertEqual(searchIDs(binding.binding.humanReadableString, bindings: [binding]), [binding.id])
    }

    func testSearchKeepsUncataloguedBindingFallbackAndNoMatchState() {
        let binding = HotkeyBinding(id: "custom-binding", command: .focusNavigation(.previous), trigger: .unassigned)
        XCTAssertEqual(searchIDs(binding.command.displayName, bindings: [binding]), [binding.id])
        XCTAssertEqual(searchIDs(binding.command.layoutCompatibility.rawValue, bindings: [binding]), [binding.id])
        let results = HotkeySettingsDisplayModel.search(
            "zzzznotfound",
            bindings: HotkeyBindingRegistry.defaults(),
            showsAdvancedHotkeys: false
        )
        XCTAssertTrue(results.groups.isEmpty)
        XCTAssertEqual(results.hiddenAdvancedMatchCount, 0)
    }

    private func hiddenAdvancedMatchCount(_ query: String, bindings: [HotkeyBinding]) -> Int {
        HotkeySettingsDisplayModel.search(query, bindings: bindings, showsAdvancedHotkeys: false)
            .hiddenAdvancedMatchCount
    }

    private func searchIDs(_ query: String, bindings: [HotkeyBinding]) -> [String] {
        HotkeySettingsDisplayModel.search(query, bindings: bindings, showsAdvancedHotkeys: true).groups
            .flatMap(\.bindings).map(\.id)
    }
}
