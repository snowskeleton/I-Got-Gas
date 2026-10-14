//
//  PumpScannerView.swift
//  I Got Gas
//
//  Live text scanning pointed at a gas pump's display.
//
//  `DataScannerViewController` does the camera, focus, preview and
//  highlighting, which is the whole reason we aren't hand-rolling an
//  `AVCaptureSession` for this. Everything interesting happens in
//  `PumpReadingParser` and `PumpScanConsensus`; this file is the glue and the
//  readout.
//
//  Nothing here dismisses itself. A lock is a suggestion, and the user taps to
//  accept it — a wrong reading must never close the sheet before they can see
//  what it decided.
//

import SwiftUI
import SwiftData
import VisionKit

// MARK: - Model

@Observable
@MainActor
final class PumpScanModel {

    enum Phase: Equatable {
        /// Live preview, waiting for something worth photographing.
        case framing
        /// Taking stills and reading them.
        case reading
        /// Read something we don't believe, and asking the user to point at
        /// the sale amount rather than guessing again.
        case needsFocus
        /// Done — showing what the stills said.
        case result
    }

    private(set) var phase: Phase = .framing
    private(set) var reading: PumpReading?

    /// How many variants agreed on the reading being shown, and how many had
    /// an opinion. Surfaced because agreement across independent reads is the
    /// only corroboration a two-number display offers.
    private(set) var agreement: (votes: Int, ballots: Int)?

    /// How close the framing is to tripping a capture, 0...1.
    private(set) var steadiness: Double = 0

    /// Numeric runs the live stream can see. Feedback only — it tells the user
    /// they are pointed at the right thing and never feeds the reading.
    private(set) var numbersInView = 0

    /// Which attempt we're on, for the progress line.
    private(set) var attempt = 0

    private var detector = PumpScanSteadiness()
    private var scanContext: PumpScanContext
    private let startedAt = Date()
    private var armed = true

    /// Held back while we ask the user for help, so declining still shows them
    /// what we had.
    private var pending: PumpBallot.Outcome?

    /// Photographs per read.
    ///
    /// Two, and the second only fires when the first came back with nothing
    /// whole: motion blur is the one failure another photograph actually
    /// fixes. Everything else is deterministic — the display isn't moving and
    /// the parser doesn't wander — so re-photographing a pump the parser has
    /// already failed on returns the identical answer. That is precisely what
    /// the three attempts here used to do: run the same failure three times at
    /// three times the cost, and then show it anyway. A reading we don't
    /// believe now asks the user instead, which is the only new information
    /// available.
    private static let maximumAttempts = 2

    var capture: (() async -> UIImage?)?

    init(scanContext: PumpScanContext) {
        self.scanContext = scanContext
    }

    var secondsElapsed: Int { Int(Date().timeIntervalSince(startedAt).rounded()) }

    // MARK: Live stream

    func observe(_ lines: [ScannedLine]) {
        guard phase == .framing else { return }

        numbersInView = lines.filter { $0.text.filter(\.isNumber).count >= 2 }.count

        let steady = detector.observe(lines)
        steadiness = detector.progress

        guard steady, armed else { return }
        armed = false
        Task { await captureAndRead() }
    }

    // MARK: Capture

    func captureAndRead() async {
        // `capturePhoto(within:)` does its own lookup; this only refuses to
        // start a read the scanner cannot possibly finish.
        guard phase != .reading, capture != nil else { return }

        let hinted = scanContext.hint != nil
        phase = .reading
        attempt = 0
        var best: PumpBallot.Outcome?

        for round in 1...Self.maximumAttempts {
            attempt = round

            let shutter = Date()
            guard let image = await capturePhoto(within: Self.captureTimeout) else {
                NSLog("pump scan: no photo after %.0f ms", Date().timeIntervalSince(shutter) * 1000)
                break
            }
            NSLog("pump scan: photo in %.0f ms", Date().timeIntervalSince(shutter) * 1000)

            let ensemble = await PumpStillRecognizer.ensemble(for: image)

            let interpreted = Date()
            let parsed = await Self.parse(ensemble, with: scanContext)
            NSLog(
                "pump scan: parsed %d of %d passes in %.0f ms",
                parsed.count, ensemble.count,
                Date().timeIntervalSince(interpreted) * 1000
            )

            let winner = PumpBallot.winner(among: parsed)

            // A no-op outside Xcode and TestFlight — see `PumpScanDebug`.
            PumpScanDebugRecorder.record(
                capture: image,
                ensemble: ensemble,
                outcome: winner,
                context: scanContext,
                attempt: round
            )

            guard let outcome = winner else { continue }

            // Keep whichever attempt got furthest, so a run of bad photos
            // still ends with the best of them rather than the last of them.
            if best == nil || rank(outcome) > rank(best!) {
                best = outcome
            }

            // Only blur is worth another photograph — see `maximumAttempts`.
            if outcome.reading.isComplete { break }
        }

        // A reading we don't trust is worth asking about, not repeating. The
        // user is standing in front of the pump; one tap settles what the
        // parser can only infer.
        if !hinted, needsHelp(best) {
            pending = best
            phase = .needsFocus
            Analytics.track(.pumpScanFocused, with: ["readSomething": best != nil])
            return
        }

        finish(with: best)
    }

    /// How long to wait for the shutter.
    ///
    /// `DataScannerViewController.capturePhoto()` has no timeout of its own
    /// and does not return at all if the scanner has stopped underneath it.
    /// Generous enough that a slow phone finishes, short enough that a stuck
    /// one becomes a message the user can act on rather than a spinner that
    /// never resolves.
    private static let captureTimeout: TimeInterval = 8

    /// Takes the photo, giving up after `seconds`.
    ///
    /// This does not cancel the capture — `capturePhoto()` is not
    /// cancellable — it stops *waiting* for it, which is the part the user is
    /// looking at.
    private func capturePhoto(within seconds: TimeInterval) async -> UIImage? {
        guard let capture else { return nil }

        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { @MainActor in await capture() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Off the main actor, deliberately.
    ///
    /// Parsing is pure, and the progress spinner is animating while it runs.
    /// Keeping it here meant a parser that got slow didn't show as slow, it
    /// showed as a frozen screen — which is exactly what happened: scoring is
    /// quartic in the number of candidates, a full-resolution photograph of a
    /// whole pump supplies plenty of them, and the scan sat on "Reading the
    /// display…" indefinitely. The ceiling in `PumpReadingParser` is the fix;
    /// this is so the next one costs a moment instead of the feature.
    private nonisolated static func parse(
        _ ensemble: [[ScannedLine]],
        with context: PumpScanContext
    ) async -> [PumpReading] {
        await Task.detached(priority: .userInitiated) {
            ensemble
                .filter { !$0.isEmpty }
                .map { PumpReadingParser.parse($0, context: context) }
        }.value
    }

    private func needsHelp(_ outcome: PumpBallot.Outcome?) -> Bool {
        guard let outcome else { return true }
        return !outcome.reading.isComplete || !outcome.reading.isPlausible
    }

    /// The user pointed at the sale amount. Read the pump again knowing it.
    func focus(on hint: PumpScanHint) {
        guard phase == .needsFocus else { return }
        scanContext.hint = hint
        Task { await captureAndRead() }
    }

    /// They'd rather see what we had than point at anything.
    func showWhatWeHave() {
        guard phase == .needsFocus else { return }
        finish(with: pending)
    }

    private func rank(_ outcome: PumpBallot.Outcome) -> Int {
        var score = outcome.votes
        if outcome.reading.isComplete { score += 100 }
        if outcome.reading.isPlausible { score += 1_000 }
        return score
    }

    private func finish(with outcome: PumpBallot.Outcome?) {
        reading = outcome?.reading
        agreement = outcome.map { ($0.votes, $0.ballots) }
        phase = .result

        let generator = UINotificationFeedbackGenerator()
        switch (outcome?.reading.isComplete ?? false, outcome?.reading.isPlausible ?? false) {
        case (true, true): generator.notificationOccurred(.success)
        case (true, false): generator.notificationOccurred(.warning)
        default: generator.notificationOccurred(.error)
        }
    }

    /// Back to the live preview for another go.
    func rescan() {
        reading = nil
        agreement = nil
        pending = nil
        attempt = 0
        scanContext.hint = nil
        phase = .framing
        detector.reset()
        steadiness = 0
        armed = true
    }
}

// MARK: - Context

extension PumpScanContext {

    /// Builds the scan context for a car, learning the expected price range
    /// from what this vehicle has actually been filled with.
    ///
    /// Falls back to the whole account before giving up entirely, so a newly
    /// added second car still benefits from the first one's history.
    static func forCar(_ car: SDCar, in context: ModelContext) -> PumpScanContext {
        PumpScanContext(
            volumeUnit: UnitPreferences.volumeUnit,
            currencyCode: UnitPreferences.currencyCode,
            priceBand: priceBand(fromRecent: recentFuelPrices(for: car, in: context))
        )
    }

    private static func recentFuelPrices(for car: SDCar, in context: ModelContext) -> [Money] {
        let fuel = ServiceKind.fuel.rawValue

        func fetch(carID: String?) -> [Money] {
            var descriptor = FetchDescriptor<SDService>(
                predicate: #Predicate<SDService> {
                    $0.deleted == false
                        && $0.kindRaw == fuel
                        && $0.volumeML > 0
                        && (carID == nil || $0.car?.id == carID)
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 12
            return ((try? context.fetch(descriptor)) ?? []).compactMap(\.costPerVolume)
        }

        let own = fetch(carID: car.id)
        return own.count >= 2 ? own : fetch(carID: nil)
    }
}

// MARK: - View

struct PumpScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let scanContext: PumpScanContext
    let onUse: (PumpReading) -> Void

    @State private var model: PumpScanModel
    @State private var handle = ScannerHandle()
    @State private var applied = false
    @State private var scanPackage: ScanPackage?
    @State private var isPackaging = false

    /// A zip waiting for the share sheet. Wrapped because `URL` can't identify
    /// a sheet on its own.
    private struct ScanPackage: Identifiable {
        let id = UUID()
        let url: URL
    }

    init(scanContext: PumpScanContext, onUse: @escaping (PumpReading) -> Void) {
        self.scanContext = scanContext
        self.onUse = onUse
        _model = State(initialValue: PumpScanModel(scanContext: scanContext))
    }

    private var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if isAvailable {
                    PumpTextScanner(
                        handle: handle,
                        onLines: { model.observe($0) },
                        onTap: { model.focus(on: $0) }
                    )
                    .ignoresSafeArea()
                    controls
                } else {
                    ContentUnavailableView(
                        "Scanning Unavailable",
                        systemImage: "camera.badge.ellipsis",
                        description: Text(
                            "This device can't scan text right now. Check that "
                            + "I Got Gas is allowed to use the camera."
                        )
                    )
                }
            }
            .navigationTitle("Scan Pump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            model.capture = { await handle.capturePhoto() }
            Analytics.track(.pumpScanOpened)
        }
        .onDisappear {
            guard !applied else { return }
            Analytics.track(
                .pumpScanAbandoned,
                with: [
                    "seconds": model.secondsElapsed,
                    "reachedResult": model.reading != nil,
                ]
            )
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 14) {
            switch model.phase {
            case .framing:
                framingGuidance
            case .reading:
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(model.attempt > 1 ? "Trying once more…" : "Reading the display…")
                        .foregroundStyle(.white)
                }
                .font(.headline)
            case .needsFocus:
                focusGuidance
            case .result:
                resultReadout
            }

            if PumpScanDebug.isEnabled, model.phase == .result || model.phase == .needsFocus {
                shareScanData
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
        .padding(16)
        .animation(.default, value: model.phase)
        .sheet(item: $scanPackage) { PumpScanShareSheet(url: $0.url) }
    }

    /// Sends the recorded scans somewhere they can be looked at.
    ///
    /// Everything still on the phone goes in one zip rather than just this
    /// scan: a reading that went wrong is only worth so much without a couple
    /// that went right to compare it against.
    @ViewBuilder
    private var shareScanData: some View {
        Button {
            isPackaging = true
            Task {
                let packaged = await Task.detached(priority: .userInitiated) {
                    PumpScanDebug.packagedScans()
                }.value
                isPackaging = false
                if let packaged { scanPackage = ScanPackage(url: packaged) }
            }
        } label: {
            HStack(spacing: 6) {
                if isPackaging {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isPackaging ? "Packaging…" : "Share Scan Data")
            }
            .font(.footnote)
        }
        .buttonStyle(.borderless)
        .tint(.white)
        .disabled(isPackaging)
    }

    @ViewBuilder
    private var framingGuidance: some View {
        Text(model.numbersInView >= 2
             ? "Hold steady…"
             : "Point at the pump's display")
            .font(.headline)
            .foregroundStyle(.white)

        Text("The photo is taken automatically once the numbers stop moving.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)

        ProgressView(value: model.steadiness)
            .tint(.white)
            .frame(maxWidth: 220)

        // The escape hatch. Steadiness can fail to trip — a shaky hand, a
        // pump whose numbers keep ticking — and the scan must never dead-end.
        Button {
            Task { await model.captureAndRead() }
        } label: {
            Label("Take Photo Now", systemImage: "camera")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .controlSize(.large)
    }

    /// Shown when the automatic read came back wrong or incomplete.
    ///
    /// Asking beats guessing again. The pump is in front of the user and the
    /// one thing the parser can never settle for itself — which of the two
    /// numbers is the money — is something they can see at a glance. Every
    /// other signal the parser has is an inference standing in for this.
    @ViewBuilder
    private var focusGuidance: some View {
        Text("Tap the total on the pump")
            .font(.headline)
            .foregroundStyle(.white)

        Text("Highlighted numbers can be tapped. Pick the one showing the "
             + "amount of money — we'll work out the rest.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)

        HStack(spacing: 10) {
            Button("Start Over") { model.rescan() }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)

            // Never a dead end: whatever we did read is still one field the
            // user doesn't have to type.
            Button("Show What You Got") { model.showWhatWeHave() }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private var resultReadout: some View {
        if let reading = model.reading, !reading.isEmpty {
            values(for: reading)

            // Which of these two leads depends on whether we believe the
            // reading. An implied price nothing like what this driver pays,
            // under a prominent blue button, is still an invitation to tap it;
            // the figures stay on screen either way, but the suggested action
            // becomes "go again".
            HStack(spacing: 10) {
                if reading.isComplete && reading.isPlausible {
                    Button("Rescan") { model.rescan() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .controlSize(.large)

                    Button {
                        apply(reading)
                    } label: {
                        Text("Use these values").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Use Anyway") { apply(reading) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .controlSize(.large)

                    Button {
                        model.rescan()
                    } label: {
                        Text("Rescan").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        } else {
            Text("Couldn't read the display")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Try filling the frame with just the numbers, and watch for glare.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Try Again") { model.rescan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func values(for reading: PumpReading) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                field(
                    reading.total?.formatted() ?? "—",
                    caption: "Total",
                    known: reading.total != nil
                )
                field(
                    reading.volume?.formatted(
                        as: reading.volumeUnit,
                        fractionDigits: reading.volumeUnit.entryFractionDigits
                    ) ?? "—",
                    caption: reading.volumeUnit.abbreviation,
                    known: reading.volume != nil
                )
            }

            // The gut-check. If this number looks nothing like what fuel costs,
            // the two values are the wrong way round and the user can see it
            // at a glance — which is as close to validation as a display with
            // only two numbers on it allows.
            if let price = reading.impliedUnitPrice {
                Text(unitPriceLabel(price, unit: reading.volumeUnit))
                    .font(.footnote)
                    .foregroundStyle(reading.isPlausible ? .white.opacity(0.7) : .orange)
            }

            if !reading.isComplete {
                Text("Only one number came through — you can type the other.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            } else if let agreement = model.agreement,
                      agreement.ballots > 1,
                      agreement.votes < agreement.ballots {
                // Only the disagreement is worth saying. The passes are the
                // same photograph under different filters, and on a real
                // capture all eight returned the identical digits — including
                // the identical dropped decimal point. Reporting that as
                // "all 8 reads agree" sold correlated passes as corroboration,
                // which is most misleading exactly when they are all wrong
                // together.
                Text("\(agreement.votes) of \(agreement.ballots) reads agree — worth a check")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func field(_ value: String, caption: String, known: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(known ? .white : .white.opacity(0.4))
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func unitPriceLabel(_ price: Decimal, unit: VolumeUnit) -> String {
        let formatted = price.formatted(
            .currency(code: scanContext.currencyCode).precision(.fractionLength(3))
        )
        return "\(formatted)/\(unit.abbreviation)"
    }

    private func apply(_ reading: PumpReading) {
        applied = true
        Analytics.track(
            .pumpScanApplied,
            with: [
                "complete": reading.isComplete,
                "plausible": reading.isPlausible,
                "seconds": model.secondsElapsed,
            ]
        )
        onUse(reading)
        dismiss()
    }
}

// MARK: - Scanner bridge

/// Lets the model ask the live scanner for a full-resolution still without
/// the view having to own the controller.
@MainActor
final class ScannerHandle {
    weak var controller: DataScannerViewController?

    func capturePhoto() async -> UIImage? {
        guard let controller else { return nil }
        do {
            return try await controller.capturePhoto()
        } catch {
            NSLog("pump scan: capture failed: %@", error.localizedDescription)
            return nil
        }
    }
}

/// Wraps `DataScannerViewController` and reports every recognized text run,
/// normalized into the geometry-light form the parser expects.
///
/// What it reports is only used to judge steadiness — see `PumpScanSteadiness`.
/// The reading comes from the still this same controller takes.
private struct PumpTextScanner: UIViewControllerRepresentable {
    let handle: ScannerHandle
    let onLines: ([ScannedLine]) -> Void

    /// Where the user says the sale amount is. Only the tapped run's position
    /// is used — at `.fast` quality the live stream knows where text is far
    /// better than what it says, which is the same split the still capture
    /// rests on.
    let onTap: (PumpScanHint) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            // Only the positions of these runs are ever used — the reading
            // comes from the still. Trading transcription quality for a faster
            // stream makes the framing settle sooner.
            qualityLevel: .fast,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        handle.controller = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(
        _ scanner: DataScannerViewController,
        coordinator: Coordinator
    ) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLines: onLines, onTap: onTap)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onLines: ([ScannedLine]) -> Void
        let onTap: (PumpScanHint) -> Void

        init(
            onLines: @escaping ([ScannedLine]) -> Void,
            onTap: @escaping (PumpScanHint) -> Void
        ) {
            self.onLines = onLines
            self.onTap = onTap
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            guard case let .text(text) = item else { return }
            let bounds = text.bounds
            let frameHeight = max(dataScanner.view.bounds.height, 1)
            let frameWidth = max(dataScanner.view.bounds.width, 1)

            let left = min(bounds.topLeft.x, bounds.bottomLeft.x)
            let right = max(bounds.topRight.x, bounds.bottomRight.x)
            let top = min(bounds.topLeft.y, bounds.topRight.y)
            let bottom = max(bounds.bottomLeft.y, bounds.bottomRight.y)

            onTap(
                PumpScanHint(
                    midX: ((left + right) / 2) / frameWidth,
                    midY: ((top + bottom) / 2) / frameHeight
                )
            )
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(allItems, in: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(allItems, in: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(allItems, in: dataScanner)
        }

        /// Bounds arrive in view coordinates; the parser only cares about
        /// relative position and size, so everything is divided through by the
        /// frame height and the view's dimensions never leak further in.
        private func report(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            let frameHeight = max(scanner.view.bounds.height, 1)
            let frameWidth = max(scanner.view.bounds.width, 1)

            let lines: [ScannedLine] = items.compactMap { item in
                guard case let .text(text) = item else { return nil }
                let bounds = text.bounds
                let top = min(bounds.topLeft.y, bounds.topRight.y)
                let bottom = max(bounds.bottomLeft.y, bounds.bottomRight.y)

                let left = min(bounds.topLeft.x, bounds.bottomLeft.x)
                let right = max(bounds.topRight.x, bounds.bottomRight.x)

                return ScannedLine(
                    text: text.transcript,
                    midX: ((left + right) / 2) / frameWidth,
                    midY: ((top + bottom) / 2) / frameHeight,
                    height: abs(bottom - top) / frameHeight
                )
            }

            guard !lines.isEmpty else { return }
            onLines(lines)
        }
    }
}

// MARK: - Recording what a scan saw

/// Whether this build is one of ours.
///
/// Xcode and TestFlight record scans; App Store installs do not. This is the
/// same condition that already decides whether the Developer menu exists, and
/// deliberately the same call — `Config` has worked out how to tell a
/// TestFlight install from a real one and there is no reason for a second
/// opinion about it in here.
///
/// It is a *runtime* switch rather than `#if DEBUG` because TestFlight and the
/// App Store are handed the very same binary; nothing compiled can tell them
/// apart. That is also why the bundles leave the phone through a share sheet
/// rather than `UIFileSharingEnabled`: that is an Info.plist key, it cannot
/// distinguish the two either, and giving every customer the Files-app run of
/// the app's Documents directory — the database included — to save an AirDrop
/// is not a trade worth making. It stays set in the Debug configuration only,
/// where it costs nothing.
enum PumpScanDebug {

    static var isEnabled: Bool { Config.appConfiguration != .AppStore }

    /// Zips everything recorded so far into one file to hand to the share
    /// sheet, or nil when there is nothing to send.
    ///
    /// `NSFileCoordinator`'s upload option is what does the zipping — the only
    /// archiver Foundation offers — and it hands back a temporary file that
    /// stops existing when the block returns, so it has to be copied out
    /// before anything else can be done with it.
    static func packagedScans() -> URL? {
        let manager = FileManager.default
        let folder = PumpScanDebugRecorder.folder
        guard let entries = try? manager.contentsOfDirectory(atPath: folder.path),
              !entries.isEmpty else { return nil }

        let destination = manager.temporaryDirectory
            .appendingPathComponent("pump-scans-\(Int(Date().timeIntervalSince1970)).zip")
        try? manager.removeItem(at: destination)

        var coordinationError: NSError?
        var packaged: URL?
        NSFileCoordinator().coordinate(
            readingItemAt: folder, options: [.forUploading], error: &coordinationError
        ) { temporary in
            do {
                try manager.copyItem(at: temporary, to: destination)
                packaged = destination
            } catch {
                NSLog("pump scan: could not package scans: %@", error.localizedDescription)
            }
        }
        if let coordinationError {
            NSLog("pump scan: could not read scans: %@", coordinationError.localizedDescription)
        }
        return packaged
    }
}

/// Hands a file to the system share sheet.
struct PumpScanShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

/// Writes everything one scan saw to a folder you can pull off the phone.
///
/// The artefact worth having is *not* raw sensor data — the app never sees
/// any. It is exactly the `UIImage` that `capturePhoto()` hands back, which is
/// the scanner's real input, already through the camera's own pipeline. Saved
/// as PNG so a second round of JPEG doesn't quietly soften the one thing these
/// displays can least afford to lose: the thin final stroke of a 1.
///
/// Saved beside it is what *this device's* Vision made of that image. iOS and
/// macOS ship different text recognizers, so a transcript taken off the phone
/// is the only way to know whether a Mac-side harness is reproducing the
/// device at all — and if it isn't, the device's own transcripts can still
/// drive the parser's tests directly, no camera required.
///
/// Compiled into every build and switched on at runtime by
/// `PumpScanDebug.isEnabled`, so it works in TestFlight as well as in Xcode
/// and stays dormant in the App Store.
enum PumpScanDebugRecorder {

    private struct Line: Codable {
        var text: String
        var midX: Double
        var midY: Double
        var height: Double
    }

    private struct Pass: Codable {
        var variant: String
        var lines: [Line]
        var totalMinorUnits: Int?
        var volumeML: Int?
        var impliedUnitPrice: String?
        var isPlausible: Bool
    }

    private struct Manifest: Codable {
        var savedAt: String
        var device: String
        var systemVersion: String
        var appVersion: String
        var attempt: Int

        /// The capture as `capturePhoto()` returned it, before anything in
        /// `PumpStillRecognizer` touches it.
        var captureWidth: Int
        var captureHeight: Int
        var captureScale: Double
        var captureOrientation: Int

        /// What the recognizer then did to it, so the harness can reproduce
        /// the same working size rather than guess at one.
        var workingDimension: Double
        var passCount: Int

        var volumeUnit: String
        var currencyCode: String
        var priceBandLow: String
        var priceBandHigh: String
        var hintMidX: Double?
        var hintMidY: Double?

        var passes: [Pass]

        /// What the app actually showed, so a bundle can be matched to the
        /// wrong number you were looking at when you took it.
        var winnerTotalMinorUnits: Int?
        var winnerVolumeML: Int?
        var winnerIsPlausible: Bool?
        var votes: Int?
        var ballots: Int?
    }

    static let folder: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("PumpScans", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// A full-resolution PNG runs to tens of megabytes and these pile up fast.
    private static let keepMostRecent = 12

    /// How many scans are on the phone and what they weigh.
    static var summary: String {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(atPath: folder.path),
              !entries.isEmpty else { return "None" }

        var bytes = 0
        if let walker = manager.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in walker {
                bytes += (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            }
        }
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        return "\(entries.count) · \(size)"
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    static func record(
        capture: UIImage,
        ensemble: [[ScannedLine]],
        outcome: PumpBallot.Outcome?,
        context: PumpScanContext,
        attempt: Int
    ) {
        guard PumpScanDebug.isEnabled else { return }

        let variants = PumpStillRecognizer.Variant.allCases.map { String(describing: $0) }

        // Re-parsed per pass rather than taking the array the ballot was given:
        // that one has the passes that read nothing filtered out of it, so it
        // cannot be indexed alongside `ensemble` and every variant after the
        // first blank one would be labelled with its neighbour's reading.
        let passes: [Pass] = ensemble.enumerated().map { index, lines in
            let reading = lines.isEmpty
                ? nil
                : PumpReadingParser.parse(lines, context: context)
            return Pass(
                variant: index < variants.count ? variants[index] : "pass\(index)",
                lines: lines.map {
                    Line(text: $0.text, midX: $0.midX, midY: $0.midY, height: $0.height)
                },
                totalMinorUnits: reading?.total?.minorUnits,
                volumeML: reading?.volume?.milliliters,
                impliedUnitPrice: reading?.impliedUnitPrice.map { "\($0)" },
                isPlausible: reading?.isPlausible ?? false
            )
        }

        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let now = Date()

        let manifest = Manifest(
            savedAt: ISO8601DateFormatter().string(from: now),
            device: deviceModel(),
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Foundation.Bundle.main
                .infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            attempt: attempt,
            captureWidth: capture.cgImage?.width ?? 0,
            captureHeight: capture.cgImage?.height ?? 0,
            captureScale: Double(capture.scale),
            captureOrientation: capture.imageOrientation.rawValue,
            workingDimension: Double(PumpStillRecognizer.workingDimension),
            passCount: ensemble.count,
            volumeUnit: context.volumeUnit.rawValue,
            currencyCode: context.currencyCode,
            priceBandLow: "\(context.priceBand.lowerBound)",
            priceBandHigh: "\(context.priceBand.upperBound)",
            hintMidX: context.hint?.midX,
            hintMidY: context.hint?.midY,
            passes: passes,
            winnerTotalMinorUnits: outcome?.reading.total?.minorUnits,
            winnerVolumeML: outcome?.reading.volume?.milliliters,
            winnerIsPlausible: outcome?.reading.isPlausible,
            votes: outcome?.votes,
            ballots: outcome?.ballots
        )

        // PNG-encoding a 12-megapixel capture is not quick, and nothing is
        // waiting on it.
        Task.detached(priority: .utility) {
            let name = "scan-"
                + stamp.string(from: now).replacingOccurrences(of: ":", with: "")
                + "-\(attempt)"
            let directory = folder.appendingPathComponent(name, isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true
                )
                if let png = capture.pngData() {
                    try png.write(to: directory.appendingPathComponent("capture.png"))
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(manifest)
                    .write(to: directory.appendingPathComponent("scan.json"))
                NSLog("pump scan: saved debug bundle %@", directory.path)
                prune()
            } catch {
                NSLog("pump scan: could not save debug bundle: %@", error.localizedDescription)
            }
        }
    }

    private static func prune() {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let oldestFirst = entries.sorted {
            let left = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            let right = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            return (left ?? .distantPast) < (right ?? .distantPast)
        }
        for stale in oldestFirst.dropLast(keepMostRecent) {
            try? manager.removeItem(at: stale)
        }
    }

    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

// MARK: - Simulator

#if DEBUG

/// `DataScannerViewController` needs a camera, so none of the above runs in the
/// simulator. This feeds canned pump text through the real parser so the
/// interpretation and the unit conversions can be exercised without hardware.
///
/// It lives in this file rather than its own so the app target's inclusion list
/// doesn't need another entry for something that never ships.
struct PumpScanSimulatorView: View {

    private struct Scenario: Identifiable {
        let id = UUID()
        let name: String
        let unit: VolumeUnit
        let currency: String
        let lines: [String]
    }

    private let scenarios: [Scenario] = [
        Scenario(
            name: "US pump, no labels",
            unit: .gallonsUS, currency: "USD",
            lines: ["42.15", "12.048"]
        ),
        Scenario(
            name: "US pump, labelled",
            unit: .gallonsUS, currency: "USD",
            lines: ["TOTAL SALE", "$42.15", "GALLONS", "12.048"]
        ),
        Scenario(
            name: "Litre pump, US account",
            unit: .gallonsUS, currency: "USD",
            lines: ["TOTAL $52.40", "LITRES 38.25"]
        ),
        Scenario(
            name: "Decimal comma",
            unit: .liters, currency: "EUR",
            lines: ["42,15", "31,25 L"]
        ),
        Scenario(
            name: "Glare — one number lost",
            unit: .gallonsUS, currency: "USD",
            lines: ["TOTAL SALE $42.15", "GALLONS"]
        ),
        Scenario(
            name: "Noise only",
            unit: .gallonsUS, currency: "USD",
            lines: ["PUMP 4", "OCTANE 87", "PLEASE PAY INSIDE"]
        ),
    ]

    var body: some View {
        List(scenarios) { scenario in
            let reading = PumpReadingParser.parse(
                scenario.lines.map { ScannedLine(text: $0) },
                context: PumpScanContext(
                    volumeUnit: scenario.unit,
                    currencyCode: scenario.currency
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.name).font(.headline)
                Text(scenario.lines.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(reading.total?.formatted() ?? "—")
                    Text(
                        reading.volume?.formatted(
                            as: reading.volumeUnit,
                            fractionDigits: reading.volumeUnit.entryFractionDigits
                        ) ?? "—"
                    )
                    if reading.isComplete {
                        Image(systemName: reading.isPlausible
                              ? "checkmark.circle.fill"
                              : "exclamationmark.triangle.fill")
                        .foregroundStyle(reading.isPlausible ? .green : .orange)
                    }
                }
                .font(.system(.body, design: .rounded, weight: .medium))
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Pump Scan Simulator")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
