import Foundation
import SwiftUI
import Unify3Sdk

let discoveryTimeout: Duration = .seconds(60)
let batchedResultTimeout: Duration = .seconds(20)

struct ExampleProgress {
  var isVisible = false
  var isIndeterminate = false
  var value = 0.0

  static let hidden = ExampleProgress()
  static let indeterminate = ExampleProgress(isVisible: true, isIndeterminate: true)

  static func percent(_ percent: Int) -> ExampleProgress {
    ExampleProgress(isVisible: true, value: Double(percent.clamped(to: 0...100)) / 100.0)
  }
}

struct ExampleStatusView: View {
  let progress: ExampleProgress
  let status: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if progress.isVisible {
        if progress.isIndeterminate {
          ProgressView()
        } else {
          ProgressView(value: progress.value)
        }
      }

      ScrollView {
        Text(status)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 160)
    }
  }
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

func performWithTimeout<T: Sendable>(
  of timeout: Duration,
  _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask {
      try await work()
    }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw ExampleError.timeout
    }
    defer { group.cancelAll() }
    return try await group.next()!
  }
}

func discoverFirstSupportedInstrument(
  using unify: Unify,
  appendStatus: @escaping @MainActor (String) -> Void
) async throws -> Instrument {
  let instrument = try await performWithTimeout(of: discoveryTimeout) { () -> Instrument? in
    // The SDK separates "keep the Bluetooth radio scan running" from
    // "read the current discovered instruments", so this task stays alive
    // while runInstrumentDiscovery() waits for an iWA to appear.
    let bluetoothScanTask = Task {
      try? await unify.runBluetoothScan()
    }

    defer {
      bluetoothScanTask.cancel()

      // stopBluetoothScan() is the call that tells the SDK to end discovery.
      // Cancelling bluetoothScanTask only stops this example from waiting on it.
      Task {
        try? await unify.stopBluetoothScan()
      }
    }

    for try await instruments in unify.runInstrumentDiscovery() {
      if !instruments.isEmpty {
        let seen = instruments
          .map { "\($0.type):\($0.serialNumber)" }
          .joined(separator: ", ")
        await appendStatus("Seen instruments: \(seen)")
      }

      if let iwa = instruments.first(where: { $0.type == .iwa }) {
        return iwa
      }
    }

    return nil
  }

  guard let instrument else {
    throw ExampleError.instrumentNotFound
  }

  return instrument
}

func configureReturnLossFrequencyTrace(
  using unify: Unify,
  serialNumber: String
) throws -> (CaaInstrumentDefinition, CaaReturnLossFrequencyTraceConfigurationResult) {
  guard
    let instrumentDefinition =
      try unify.getInstrumentDefinition(serialNumber: serialNumber).caaInstrumentDefinition
  else {
    throw ExampleError.expectedCaaInstrumentDefinition
  }

  // Build a trace that matches the connected instrument. The SDK validates this
  // request before either the return loss test or the OSL calibration starts.
  let test = Test(
    traces: [
      .caaReturnLossFrequencyTrace(
        CaaReturnLossFrequencyTrace(
          format: .magnitudeDb,
          instrumentSerialNumber: serialNumber,
          instrumentModel: instrumentDefinition.model,
          frequencyRangeHz: instrumentDefinition.frequencyRangeHz,
          numberOfPoints: 401,
          durationS: 60
        ))
    ],
    cardinality: .single
  )

  let testConfigurationResult = try unify.configureTest(test: test)
  guard testConfigurationResult.valid else {
    throw ExampleError.invalidTestConfiguration
  }

  guard
    let traceConfiguration = testConfigurationResult.traceConfigurationResults.first?
      .caaReturnLossFrequencyTraceConfigurationResult
  else {
    throw ExampleError.expectedCaaReturnLossFrequencyTraceConfigurationResult
  }

  return (instrumentDefinition, traceConfiguration)
}

@MainActor
func disconnectConnectedInstrument(
  using unify: Unify,
  serialNumber: String,
  appendStatus: (String) -> Void
) async {
  appendStatus("Disconnecting \(serialNumber)...")

  do {
    try await unify.disconnectInstrument(serialNumber: serialNumber)
    appendStatus("Disconnected \(serialNumber)")
  } catch {
    appendStatus("Disconnect failed: \(error.localizedDescription)")
  }
}

enum ExampleError: LocalizedError {
  case connectionFailed(ConnectionResult)
  case connectFirst
  case expectedCaaInstrumentDefinition
  case expectedCaaReturnLossFrequencyTraceConfigurationResult
  case expectedOslCalibrationConfigurationResult
  case instrumentNotFound
  case invalidTestConfiguration
  case missingOslCalibration
  case missingTraceId
  case noBatchedResult
  case noCalibrationStepReady
  case runTestFirst
  case timeout

  var errorDescription: String? {
    switch self {
    case .connectionFailed(let result):
      "Connect result: \(result)"
    case .connectFirst:
      "Connect first"
    case .expectedCaaInstrumentDefinition:
      "Expected a CAA instrument definition"
    case .expectedCaaReturnLossFrequencyTraceConfigurationResult:
      "Missing return loss trace configuration"
    case .expectedOslCalibrationConfigurationResult:
      "Expected an OSL calibration configuration result"
    case .instrumentNotFound:
      "No supported iWA instrument was discovered"
    case .invalidTestConfiguration:
      "Test configuration was invalid"
    case .missingOslCalibration:
      "No OSL calibration was returned for this trace"
    case .missingTraceId:
      "The configured trace did not include a trace ID"
    case .noBatchedResult:
      "No batched result was returned"
    case .noCalibrationStepReady:
      "No enabled calibration step is ready"
    case .runTestFirst:
      "Run the return loss test first"
    case .timeout:
      "Timed out"
    }
  }
}
