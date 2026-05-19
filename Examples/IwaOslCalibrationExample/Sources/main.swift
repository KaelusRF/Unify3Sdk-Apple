import Foundation
import Unify3Sdk

// `Unify.shared` is the main entry point for talking to instruments through the SDK.
let unify = Unify.shared

// Start by scanning for nearby instruments and waiting for discovery updates.
let instrument = try await discoverFirstIwa(using: unify)

// Connect to the instrument we just discovered.
print("Connecting to iWA \(instrument.serialNumber)...")
let connectionResult = try await unify.connectInstrument(serialNumber: instrument.serialNumber)
guard connectionResult == .success else {
  throw UnifyError.connectionFailed(reason: "Result was \(connectionResult)")
}

// Read the connected instrument definition so the example can request a trace
// that matches the hardware's supported settings.
guard
  let instrumentDefinition =
    try unify
    .getInstrumentDefinition(serialNumber: instrument.serialNumber)
    .caaInstrumentDefinition
else {
  throw UnifyError.expectedCaaInstrumentDefinition
}

// Configure a single return loss vs frequency trace.
let test = Test(
  traces: [
    .caaReturnLossFrequencyTrace(
      CaaReturnLossFrequencyTrace(
        // `.complex` returns each point as I/Q data instead of a scalar value.
        format: .complex,
        instrumentSerialNumber: instrument.serialNumber,
        instrumentModel: instrumentDefinition.model,
        frequencyRangeHz: instrumentDefinition.frequencyRangeHz,
        numberOfPoints: 401,
        // `durationS` is still part of the trace definition even though this
        // example stops after configuration.
        durationS: 60
      ))
  ],
  cardinality: .single
)

// Configure the trace before calibrating so the SDK can tell us which OSL
// calibration is required for the requested trace.
let testConfigurationResult = try unify.configureTest(test: test)

guard
  let traceConfiguration = testConfigurationResult.traceConfigurationResults.first?
    .caaReturnLossFrequencyTraceConfigurationResult
else {
  throw UnifyError.expectedCaaReturnLossFrequencyTraceConfigurationResult
}

guard let calibration = traceConfiguration.calibration else {
  throw UnifyError.missingOslCalibration
}

// Show the user the default calibration kit the SDK selected from the trace
// configuration result.
print("Configured return loss trace for \(instrumentDefinition.model)")
print("Using calibration kit: \(calibration.calKitName)")

// Configure the calibration itself before starting the step-by-step workflow.
let calibrationConfigurationResult = try unify.configureCalibration(
  calibration: .oslCalibration(calibration)
)
guard
  let oslConfigurationResult = calibrationConfigurationResult.oslCalibrationConfigurationResult
else {
  throw UnifyError.expectedOslCalibrationConfigurationResult
}

print(
  "Calibration configured for \(Int(calibration.frequencyRangeHz.start)) Hz to \(Int(calibration.frequencyRangeHz.end)) Hz."
)

// `runCalibration()` streams the current calibration state. Each update tells us
// which step is ready, which steps are already complete, and what instruction
// text should be shown before the next step runs.
var lastStartedStepID: String?

for try await calibrationState in unify.runCalibration() {
  guard let oslState = calibrationState.oslCalibrationState else {
    continue
  }

  if oslState.steps.allSatisfy(\.complete) {
    print("Calibration complete!")
    break
  }

  print("")
  print("Calibration state:")
  for step in oslState.steps {
    let status = step.complete ? "complete" : (step.enabled ? "ready" : "waiting")
    print("- \(step.name): \(status)")
  }

  guard let nextStep = oslState.steps.first(where: { $0.enabled && !$0.complete }) else {
    continue
  }

  guard nextStep.id != lastStartedStepID else {
    continue
  }

  lastStartedStepID = nextStep.id

  print("")
  print("Next step: \(nextStep.name)")
  print(nextStep.instruction)
  print("Press Enter to run this step.")
  _ = readLine()

  // Each calibration step reports progress separately from the overall
  // calibration state stream, so run the enabled step and then wait for the
  // next state update.
  for try await progress in unify.runCalibrationStep(stepId: nextStep.id) {
    if progress < 0 {
      print("Step progress: indeterminate")
    } else {
      print("Step progress: \(Int(progress * 100))%")
    }
  }

  print("Completed step: \(nextStep.name)")
}

// Wrap async work in a timeout so discovery fails explicitly instead of waiting
// forever when no instrument appears.
func discoverFirstIwa(using unify: Unify) async throws -> Instrument {
  let instrument = try await performWithTimeout(of: .seconds(60)) { () -> Instrument? in
    // `runBluetoothScan()` stays alive while the SDK scan is active, so keep it
    // in a task while discovery waits for an instrument to appear.
    let bluetoothScanTask = Task {
      try? await unify.runBluetoothScan()
    }

    // Stop the scan when discovery finishes.
    // Cancelling the task only stops waiting for `runBluetoothScan()` to return;
    // `stopBluetoothScan()` is what actually tells the SDK to stop scanning.
    defer {
      bluetoothScanTask.cancel()
      Task {
        try? await unify.stopBluetoothScan()
      }
    }

    // Discovery yields instruments the SDK can currently see.
    // Here we pick the first iWA so the example has something concrete to use.
    for try await instruments in unify.runInstrumentDiscovery() {
      if let iwa = instruments.first(where: { $0.type == .iwa }) {
        return iwa
      }
    }

    return nil
  }

  guard let instrument else {
    throw UnifyError.instrumentNotFound
  }

  return instrument
}

func performWithTimeout<T: Sendable>(
  of timeout: Duration,
  _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup { group in
    group.addTask {
      try await work()
    }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw UnifyError.timeout
    }
    defer { group.cancelAll() }
    return try await group.next()!
  }
}

enum UnifyError: Error {
  case connectionFailed(reason: String)
  case expectedCaaInstrumentDefinition
  case expectedCaaReturnLossFrequencyTraceConfigurationResult
  case expectedOslCalibrationConfigurationResult
  case instrumentNotFound
  case missingOslCalibration
  case timeout
}
