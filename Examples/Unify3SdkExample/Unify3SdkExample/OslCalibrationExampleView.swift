import Foundation
import SwiftUI
import Unify3Sdk

struct OslCalibrationExampleView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var model = OslCalibrationExampleModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Button("1) Discover Instrument") {
          model.discoverInstrument()
        }
        .buttonStyle(.borderedProminent)

        Button("2) Connect") {
          model.connectInstrument()
        }
        .buttonStyle(.borderedProminent)

        Button("3) Prepare Calibration") {
          model.prepareCalibration()
        }
        .buttonStyle(.borderedProminent)

        Button(model.nextStepButtonTitle) {
          model.runNextCalibrationStep()
        }
        .buttonStyle(.borderedProminent)

        ExampleStatusView(progress: model.progress, status: model.status)
      }
      .padding()
    }
    .navigationTitle("OSL Calibration")
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Back to Examples") {
          Task {
            await model.disconnectIfNeeded()
            dismiss()
          }
        }
      }
    }
    .task {
      model.startLogStream()
    }
    .onDisappear {
      Task {
        await model.disconnectIfNeeded()
      }
    }
  }
}

@MainActor
final class OslCalibrationExampleModel: ObservableObject {
  @Published var nextStepButtonTitle = "4) Run Next Step"
  @Published var progress = ExampleProgress.hidden
  @Published var status = ""

  private let unify = Unify.shared
  private var discoveredInstrument: Instrument?
  private var connectedSerialNumber: String?
  private var latestCalibrationState: OslCalibrationState?
  private var lastCalibrationSummary: String?
  private var lastStartedStepID: String?
  private var calibrationTask: Task<Void, Never>?
  private var logTask: Task<Void, Never>?

  init() {
    do {
      try unify.setLogLevels(minLevel: .info, maxLevel: .error)
      appendStatus("OSL Calibration example")
      appendStatus("Flow: Discover -> Connect -> Prepare -> Run Next Step")
    } catch {
      appendStatus("Set log levels failed: \(error.localizedDescription)")
    }
  }

  deinit {
    calibrationTask?.cancel()
    logTask?.cancel()
  }

  func startLogStream() {
    guard logTask == nil else { return }

    let unify = unify
    logTask = Task { [weak self] in
      do {
        for try await log in unify.getLogs() {
          let message = "[\(log.time)] \(log.level)/\(log.logger): \(log.message)"
          self?.appendStatus(message)
        }
      } catch {
        self?.appendStatus("Log stream ended: \(error.localizedDescription)")
      }
    }
  }

  func discoverInstrument() {
    clearStatus()

    Task { [weak self] in
      guard let self else { return }

      do {
        appendStatus("Starting discovery (up to 60s)...")
        let instrument = try await discoverFirstSupportedInstrument(
          using: unify,
          appendStatus: appendStatus
        )
        discoveredInstrument = instrument
        appendStatus("Discovered \(instrument.type) \(instrument.serialNumber)")
      } catch {
        appendStatus("Discover failed: \(error.localizedDescription)")
      }
    }
  }

  func connectInstrument() {
    clearStatus()

    Task { [weak self] in
      guard let self else { return }

      do {
        guard let instrument = discoveredInstrument else {
          throw ExampleError.instrumentNotFound
        }

        appendStatus("Connecting to \(instrument.serialNumber)...")
        let result = try await unify.connectInstrument(serialNumber: instrument.serialNumber)
        guard result == .success else {
          throw ExampleError.connectionFailed(result)
        }

        connectedSerialNumber = instrument.serialNumber
        appendStatus("Connected \(instrument.serialNumber)")
      } catch {
        appendStatus("Connect failed: \(error.localizedDescription)")
      }
    }
  }

  func prepareCalibration() {
    clearStatus()

    Task { [weak self] in
      guard let self else { return }

      do {
        guard let serialNumber = connectedSerialNumber else {
          throw ExampleError.connectFirst
        }

        lastStartedStepID = nil
        latestCalibrationState = nil
        lastCalibrationSummary = nil
        updateNextStepButtonTitle()

        // The calibration depends on the trace you plan to measure, so the
        // example configures the same return loss trace used by the test screen.
        let (instrumentDefinition, traceConfiguration) = try configureReturnLossFrequencyTrace(
          using: unify,
          serialNumber: serialNumber
        )

        guard let calibration = traceConfiguration.calibration else {
          throw ExampleError.missingOslCalibration
        }

        let configurationResult = try unify.configureCalibration(
          calibration: .oslCalibration(calibration)
        )

        guard
          let oslConfigurationResult = configurationResult.oslCalibrationConfigurationResult
        else {
          throw ExampleError.expectedOslCalibrationConfigurationResult
        }

        guard oslConfigurationResult.validationErrors.isEmpty else {
          let validationErrors = oslConfigurationResult.validationErrors
            .map { "\($0.type)" }
            .joined(separator: ", ")
          throw ExampleTextError("Calibration configuration was invalid: \(validationErrors)")
        }

        appendStatus(
          "Configured \(instrumentDefinition.model) for "
            + "\(calibration.frequencyRangeHz.start)..\(calibration.frequencyRangeHz.end) Hz"
        )
        appendStatus("Calibration ready: \(calibration.calKitName)")

        observeCalibrationState()
      } catch {
        appendStatus("Prepare failed: \(error.localizedDescription)")
      }
    }
  }

  func runNextCalibrationStep() {
    clearStatus()

    Task { [weak self] in
      guard let self else { return }

      do {
        guard
          let nextStep = latestCalibrationState?.steps.first(where: { $0.enabled && !$0.complete })
        else {
          throw ExampleError.noCalibrationStepReady
        }

        if nextStep.id == lastStartedStepID {
          appendStatus("Waiting for next calibration state update")
          return
        }

        lastStartedStepID = nextStep.id
        appendStatus("Running step: \(nextStep.name)")
        appendStatus(nextStep.instruction)
        progress = .indeterminate

        // Each step has its own progress stream. When it finishes, runCalibration()
        // will emit the next overall calibration state.
        for try await stepProgress in unify.runCalibrationStep(stepId: nextStep.id) {
          if stepProgress < 0 {
            progress = .indeterminate
          } else {
            let percent = Int((stepProgress * 100).rounded()).clamped(to: 0...100)
            progress = .percent(percent)
          }
        }

        progress = .hidden
        appendStatus("Completed step: \(nextStep.name)")
      } catch {
        progress = .hidden
        appendStatus("Step failed: \(error.localizedDescription)")
      }
    }
  }

  func disconnectIfNeeded() async {
    calibrationTask?.cancel()

    guard let serialNumber = connectedSerialNumber else { return }
    connectedSerialNumber = nil

    await disconnectConnectedInstrument(
      using: unify,
      serialNumber: serialNumber,
      appendStatus: appendStatus
    )
  }

  private func observeCalibrationState() {
    calibrationTask?.cancel()

    let unify = unify
    calibrationTask = Task { [weak self] in
      do {
        // runCalibration() tells the UI which calibration step is ready and
        // which steps are already complete.
        for try await calibrationState in unify.runCalibration() {
          guard let oslState = calibrationState.oslCalibrationState else {
            continue
          }

          self?.handleCalibrationState(oslState)
        }
      } catch {
        self?.appendStatus("Calibration state failed: \(error.localizedDescription)")
      }
    }
  }

  private func handleCalibrationState(_ state: OslCalibrationState) {
    latestCalibrationState = state

    let summary = state.steps
      .map { step in
        let stepStatus = step.complete ? "complete" : (step.enabled ? "ready" : "waiting")
        return "- \(step.name): \(stepStatus)"
      }
      .joined(separator: "\n")

    if summary != lastCalibrationSummary {
      appendStatus("Calibration state:\n\(summary)")
      lastCalibrationSummary = summary
    }

    updateNextStepButtonTitle()

    if state.steps.allSatisfy(\.complete) {
      appendStatus("Calibration complete")
    }
  }

  private func updateNextStepButtonTitle() {
    if let nextStepName = latestCalibrationState?.steps.first(where: { $0.enabled && !$0.complete })?.name {
      nextStepButtonTitle = "4) Run \(nextStepName) Step"
    } else {
      nextStepButtonTitle = "4) Run Next Step"
    }
  }

  private func clearStatus() {
    progress = .hidden
    status = ""
  }

  private func appendStatus(_ message: String) {
    status.append(message)
    status.append("\n\n")
  }
}

struct ExampleTextError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }
}
