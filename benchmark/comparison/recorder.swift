// ScreenCaptureKit-based screen recorder for the benchmark suite.
//
// Build:
//   swiftc -O -framework AVFoundation -framework ScreenCaptureKit \
//          -framework CoreGraphics -framework CoreMedia \
//          recorder.swift -o recorder
//
// Run:
//   ./recorder <seconds> <output.mp4>                       # full display
//   ./recorder <seconds> <output.mp4> --rect x y w h        # cropped region
//
// Why ScreenCaptureKit and not AVCaptureScreenInput
// -------------------------------------------------
// AVCaptureScreenInput is deprecated as of macOS 14 and silently produces
// "Cannot Record" errors on macOS 26+ even with full Screen Recording perm.
// Apple's replacement is ScreenCaptureKit / SCStream, which works for
// non-bundled CLI binaries with the standard Screen Recording grant. The
// SCStream callbacks deliver CMSampleBuffers we feed directly into an
// AVAssetWriter — .mp4 output.
//
// Why --rect instead of --pid (window capture)
// --------------------------------------------
// SCContentFilter(desktopIndependentWindow:) requires the CoreGraphics
// Server (CGS) to be initialised in the calling process. When two recorder
// instances are spawned simultaneously via posix_spawn with responsibility
// disclaim, CGS is not yet set up and raises an assertion:
//   Assertion failed: (did_initialize), CGS_REQUIRE_INIT, CGInitialization.c
// Using a display filter + SCStreamConfiguration.sourceRect avoids CGS
// entirely and works from any disclaimed non-GUI process.

import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia

@available(macOS 13.0, *)
enum CaptureTarget {
    case display(SCDisplay)                 // full display
    case region(SCDisplay, CGRect)          // display filter + sourceRect crop
}

// ---------------------------------------------------------------------------
// Recorder class — wraps SCStream + AVAssetWriter
// ---------------------------------------------------------------------------

@available(macOS 13.0, *)
final class SCKRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    private let outputURL: URL
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false
    private var firstPts: CMTime?
    private var frameCount = 0
    private var appendedCount = 0
    private var droppedCount = 0
    private let writerQueue = DispatchQueue(label: "recorder.writer", qos: .userInteractive)

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    private func log(_ msg: String) {
        FileHandle.standardError.write("recorder: \(msg)\n".data(using: .utf8)!)
    }

    func start(target: CaptureTarget) async throws {
        let filter: SCContentFilter
        let requestedW: Int
        let requestedH: Int
        var sourceRect: CGRect? = nil

        switch target {
        case .display(let display):
            log("display \(display.width)x\(display.height) (id=\(display.displayID))")
            filter = SCContentFilter(display: display, excludingWindows: [])
            requestedW = display.width * 2
            requestedH = display.height * 2
        case .region(let display, let rect):
            log("region \(Int(rect.width))x\(Int(rect.height)) @ (\(Int(rect.minX)),\(Int(rect.minY))) on display \(display.displayID)")
            filter = SCContentFilter(display: display, excludingWindows: [])
            requestedW = Int(rect.width) * 2
            requestedH = Int(rect.height) * 2
            sourceRect = rect
        }

        // -------------------------------------------------------- Stream config
        // Coordinates and dimensions are in logical points (Retina factor handled
        // by requesting 2× pixel dimensions). AVAssetWriter is initialised lazily
        // on the first real CVPixelBuffer so the actual encoded size is exact.
        let config = SCStreamConfiguration()
        config.width = requestedW
        config.height = requestedH
        if let rect = sourceRect {
            config.sourceRect = rect
        }
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 6
        config.showsCursor = false
        config.scalesToFit = true
        config.capturesAudio = false           // explicit — default may be true
        config.pixelFormat = kCVPixelFormatType_32BGRA

        log("config requested \(requestedW)x\(requestedH) @60fps BGRA, audio=off")

        // Asset writer is created LAZILY in the first sample callback (after
        // we know the real pixel dimensions from CVPixelBuffer).
        try? FileManager.default.removeItem(at: outputURL)

        // -------------------------------------------------------- Create stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writerQueue)
        self.stream = stream

        try await stream.startCapture()
        log("SCStream started")
    }

    /// Build AVAssetWriter + pixel-buffer adaptor using real dimensions
    /// from the first CVPixelBuffer.
    private func buildWriter(width: Int, height: Int) -> Bool {
        do {
            let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey:      12_000_000,
                    AVVideoMaxKeyFrameIntervalKey: 60,
                ],
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else {
                log("writer.canAdd(input) returned false")
                return false
            }
            writer.add(input)

            // Pixel buffer adaptor — handles BGRA → encoder pixel format
            // conversion without the silent format-mismatch failures that
            // happen when you append raw CMSampleBuffers directly.
            let pixelAttrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: pixelAttrs
            )

            self.assetWriter = writer
            self.videoInput = input
            self.pixelAdaptor = adaptor
            log("AVAssetWriter + pixel adaptor built: \(width)x\(height) h264 12Mbps (mp4)")
            return true
        } catch {
            log("buildWriter failed: \(error.localizedDescription)")
            return false
        }
    }

    func stop() async throws {
        guard let stream = self.stream else { return }
        try await stream.stopCapture()
        log("SCStream stopped — frames received: \(frameCount), appended: \(appendedCount), dropped: \(droppedCount)")

        if let writer = assetWriter {
            log("writer status before finalise: \(writer.statusDescription)")
            if writer.status == .failed {
                logFullError(writer.error, label: "writer status before finalise")
            }
        }

        // Flush writer.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writerQueue.async { [weak self] in
                self?.videoInput?.markAsFinished()
                self?.assetWriter?.finishWriting {
                    cont.resume()
                }
            }
        }
        if let writer = assetWriter {
            log("writer status after finalise: \(writer.statusDescription)")
            logFullError(writer.error, label: "writer error after finalise")
        }
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .screen, sampleBuffer.isValid else { return }

        frameCount += 1
        if frameCount == 1 {
            log("first sample buffer received")
        } else if frameCount % 60 == 0 {
            log("\(frameCount) frames received (\(appendedCount) appended, \(droppedCount) dropped)")
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            droppedCount += 1
            return
        }

        // ---------- Lazy writer init on first sample
        if assetWriter == nil {
            let realW = CVPixelBufferGetWidth(imageBuffer)
            let realH = CVPixelBufferGetHeight(imageBuffer)
            let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
            log("real CVPixelBuffer: \(realW)x\(realH) format=0x\(String(pixelFormat, radix: 16))")
            if !buildWriter(width: realW, height: realH) {
                droppedCount += 1
                return
            }
        }

        // Normalise pts to start from 0 — AVAssetWriter has issues with the
        // very large host-time PTS values SCK emits (~388225s = 4.5 days).
        let rawPts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstPts == nil {
            firstPts = rawPts
        }
        let pts = CMTimeSubtract(rawPts, firstPts!)

        if !sessionStarted {
            let started = assetWriter?.startWriting() ?? false
            log("writer.startWriting() returned \(started)")
            if !started {
                logFullError(assetWriter?.error, label: "startWriting")
                droppedCount += 1
                return
            }
            assetWriter?.startSession(atSourceTime: .zero)
            sessionStarted = true
            log("writer session started at zero — status=\(assetWriter?.statusDescription ?? "?")")
            if assetWriter?.status == .failed {
                logFullError(assetWriter?.error, label: "after startSession")
            }
        }

        guard videoInput?.isReadyForMoreMediaData == true else {
            droppedCount += 1
            return
        }

        if pixelAdaptor?.append(imageBuffer, withPresentationTime: pts) == true {
            appendedCount += 1
        } else {
            droppedCount += 1
            if droppedCount == 1 {
                logFullError(assetWriter?.error, label: "first append (adaptor)")
            }
        }
    }

    private func logFullError(_ error: Error?, label: String) {
        guard let err = error as NSError? else {
            log("\(label): no error object")
            return
        }
        log("\(label) error → domain=\(err.domain) code=\(err.code) "
            + "msg=\(err.localizedDescription)")
        if let underlying = err.userInfo[NSUnderlyingErrorKey] as? NSError {
            log("  underlying: domain=\(underlying.domain) code=\(underlying.code) "
                + "msg=\(underlying.localizedDescription)")
        }
        if let reason = err.localizedFailureReason {
            log("  reason: \(reason)")
        }
        if let suggestion = err.localizedRecoverySuggestion {
            log("  suggestion: \(suggestion)")
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log("stream stopped with error: \(error.localizedDescription)")
    }
}

@available(macOS 13.0, *)
extension AVAssetWriter.Status {
    var rawValue: Int {
        switch self {
        case .unknown: return 0
        case .writing: return 1
        case .completed: return 2
        case .failed: return 3
        case .cancelled: return 4
        @unknown default: return -1
        }
    }
}

extension AVAssetWriter {
    var statusDescription: String {
        switch status {
        case .unknown: return "unknown"
        case .writing: return "writing"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        @unknown default: return "?"
        }
    }
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

@main
struct Main {
    static func log(_ msg: String) {
        FileHandle.standardError.write("recorder: \(msg)\n".data(using: .utf8)!)
    }

    /// Poll SCShareableContent until the user grants ScreenCaptureKit consent.
    ///
    /// macOS 14+ has a TWO-LEVEL permission for screen recording:
    ///   1. CGRequestScreenCaptureAccess — old API, lets `screencapture`-style
    ///      tools read the framebuffer.
    ///   2. ScreenCaptureKit consent — separate prompt for SCStream apps.
    ///
    /// Even with the old toggle ON, SCK shows its OWN consent dialog the
    /// first time a new bundle ID asks. We open System Settings, then poll
    /// up to 120 s — once the user toggles `recorder.app` ON the next call
    /// to `SCShareableContent` succeeds and we proceed without re-running.
    @available(macOS 13.0, *)
    static func waitForDisplay() async -> SCDisplay? {
        var openedSettings = false
        let deadline = Date(timeIntervalSinceNow: 120)
        var attempt = 0

        while Date() < deadline {
            attempt += 1
            do {
                let content = try await SCShareableContent
                    .excludingDesktopWindows(false, onScreenWindowsOnly: true)
                if let display = content.displays.first {
                    if attempt > 1 {
                        log("✓ SCK permission granted on attempt \(attempt).")
                    }
                    return display
                }
                log("SCShareableContent returned 0 displays — waiting...")
            } catch {
                if !openedSettings {
                    log("ScreenCaptureKit consent missing — opening System Settings.")
                    log("⚠  In the list find 'recorder.app' (NOT the old 'recorder')")
                    log("    and toggle it ON. This recorder will continue automatically.")
                    log("    Don't close this terminal.")
                    openSystemSettingsScreenCapture()
                    openedSettings = true
                } else if attempt % 5 == 0 {
                    log("still waiting for SCK consent... attempt \(attempt) "
                        + "(\(Int(deadline.timeIntervalSinceNow))s left)")
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return nil
    }

    static func openSystemSettingsScreenCapture() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ]
        try? proc.run()
    }

    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 3, let duration = Double(args[1]) else {
            log("Usage: recorder <seconds> <output.mp4> [--rect x y w h]")
            exit(2)
        }
        let outputURL = URL(fileURLWithPath: args[2])

        // Parse optional --rect x y w h argument (logical-point coordinates).
        var targetRect: CGRect? = nil
        if args.count >= 8, args[3] == "--rect",
           let x = Double(args[4]), let y = Double(args[5]),
           let w = Double(args[6]), let h = Double(args[7]) {
            targetRect = CGRect(x: x, y: y, width: w, height: h)
            log("crop region \(Int(w))x\(Int(h)) @ (\(Int(x)),\(Int(y)))")
        }

        if #unavailable(macOS 13.0) {
            log("❌ ScreenCaptureKit needs macOS 13+ — got older.")
            exit(7)
        }

        // Touch CGRequestScreenCaptureAccess once — it triggers the legacy
        // dialog if THAT toggle hasn't been set yet. Doesn't gate SCK.
        log("checking legacy Screen Recording permission...")
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }

        // Real gate — wait for SCK consent.
        guard let display = await waitForDisplay() else {
            log("❌ ScreenCaptureKit consent NOT granted within 120 s — aborting.")
            log("   Open System Settings → Privacy & Security → Screen Recording")
            log("   and enable 'recorder.app', then re-run.")
            exit(5)
        }

        let target: CaptureTarget = targetRect.map { .region(display, $0) } ?? .display(display)

        let dimDesc: String
        switch target {
        case .display(let d): dimDesc = "display \(d.width)x\(d.height)"
        case .region(_, let r): dimDesc = "region \(Int(r.width))x\(Int(r.height)) @ (\(Int(r.minX)),\(Int(r.minY)))"
        }
        log("✓ ScreenCaptureKit ready · \(dimDesc)")

        let recorder = SCKRecorder(outputURL: outputURL)
        do {
            try await recorder.start(target: target)
            log("recording for \(duration)s via ScreenCaptureKit...")
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            log("stopping...")
            try await recorder.stop()
        } catch {
            log("❌ error: \(error.localizedDescription)")
            exit(6)
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = (attrs?[.size] as? UInt64) ?? 0
        if size < 1024 {
            log("WARNING — output is suspiciously small (\(size) bytes)")
            exit(8)
        }
        print("Recorded \(duration)s → \(outputURL.path) (\(size / 1024) KB)")
    }
}
