// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/OmniNull/OmniWM

import AppKit

@MainActor
final class WorkspaceSwipeBackdrop {
    private struct Captured {
        let displayId: CGDirectDisplayID
        let frame: CGRect
        let image: CGImage
    }

    private let wallpaperCache: OverviewWallpaperCache
    private let capture: (CGRect) -> CGImage?
    private var captured: Captured?

    init(
        wallpaperCache: OverviewWallpaperCache = OverviewWallpaperCache(),
        capture: @escaping (CGRect) -> CGImage? = { SkyLight.shared.captureWallpaper(in: $0) }
    ) {
        self.wallpaperCache = wallpaperCache
        self.capture = capture
    }

    func image(for monitor: Monitor) -> CGImage? {
        if let image = wallpaperCache.image(
            for: monitor.displayId,
            maxPixelSize: OverviewWallpaperCache.bucketedPixelSize(max(monitor.frame.width, monitor.frame.height))
        ) { return image }
        if let captured, captured.displayId == monitor.displayId, captured.frame == monitor.frame {
            return captured.image
        }
        guard let image = capture(ScreenCoordinateSpace.toWindowServer(rect: monitor.frame)),
              image.width >= Int(monitor.frame.width), image.height >= Int(monitor.frame.height)
        else { return nil }
        captured = Captured(displayId: monitor.displayId, frame: monitor.frame, image: image)
        return image
    }
}
