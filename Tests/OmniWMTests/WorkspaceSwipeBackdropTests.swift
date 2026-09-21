// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import XCTest

@MainActor
final class WorkspaceSwipeBackdropTests: XCTestCase {
    func testMissingWallpaperFileUsesAndCachesRealDesktopImage() throws {
        let wallpaper = OverviewWallpaperCache()
        wallpaper.desktopImageURL = { _ in URL(fileURLWithPath: "/nonexistent/swipe-wallpaper.png") }
        let image = try makeImage()
        var captures = 0
        let backdrop = WorkspaceSwipeBackdrop(wallpaperCache: wallpaper) { _ in
            captures += 1
            return image
        }

        XCTAssertTrue(backdrop.image(for: monitor) === image)
        XCTAssertTrue(backdrop.image(for: monitor) === image)
        XCTAssertEqual(captures, 1)
    }

    func testMissingOrCroppedDesktopImageCannotBecomeBackdrop() throws {
        let wallpaper = OverviewWallpaperCache()
        wallpaper.desktopImageURL = { _ in nil }
        let missing = WorkspaceSwipeBackdrop(wallpaperCache: wallpaper) { _ in nil }
        XCTAssertNil(missing.image(for: monitor))
        let croppedImage = try makeImage(width: 1)
        let cropped = WorkspaceSwipeBackdrop(wallpaperCache: wallpaper) { _ in croppedImage }
        XCTAssertNil(cropped.image(for: monitor))
    }

    func testWallpaperSelectionExcludesBackstopOtherDisplaysAndAppWindows() {
        let frame = CGRect(x: 0, y: 0, width: 4, height: 3)
        let desktop = CGWindowLevelForKey(.desktopWindow)
        let windows = [
            window(1, level: desktop - 3, frame: frame),
            window(2, level: desktop - 1, frame: frame.offsetBy(dx: 4, dy: 0)),
            window(3, level: 0, frame: frame),
            window(4, level: desktop - 1, frame: frame)
        ]
        XCTAssertEqual(SkyLight.wallpaperWindowId(in: windows, frame: frame), 4)
        XCTAssertNil(SkyLight.wallpaperWindowId(in: Array(windows.prefix(3)), frame: frame))
    }

    func testCaptureBridgeRejectsMalformedResultsAndRetainsImage() throws {
        XCTAssertNil(SkyLight.firstCapturedImage(in: [] as CFArray))
        XCTAssertNil(SkyLight.firstCapturedImage(in: ["not an image"] as CFArray))
        let image = try autoreleasepool {
            try XCTUnwrap(SkyLight.firstCapturedImage(in: [try makeImage()] as CFArray))
        }
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 3)
    }

    private var monitor: Monitor {
        let frame = CGRect(x: 0, y: 0, width: 4, height: 3)
        return Monitor(
            id: .init(displayId: 999), displayId: 999, frame: frame, visibleFrame: frame,
            hasNotch: false, name: "Backdrop test"
        )
    }

    private func window(_ id: UInt32, level: Int32, frame: CGRect) -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowLayer as String: level,
            kCGWindowBounds as String: frame.dictionaryRepresentation
        ]
    }

    private func makeImage(width: Int = 4) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: 3, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: 3))
        return try XCTUnwrap(context.makeImage())
    }
}
