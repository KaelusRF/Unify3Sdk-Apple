import Foundation
import Unify3Sdk

// `Unify.shared` is the main entry point for talking to instruments through the SDK.
let unify = Unify.shared

// Start by scanning for nearby instruments and waiting for discovery updates.
let instrument = try await performWithTimeout(of: .seconds(60)) { () -> Instrument? in
    // `runBluetoothScan()` stays alive while the SDK scan is active, so we keep it in
    // a task while discovery waits for instruments to appear.
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
    // Here we pick the first iWA so we have something concrete to connect to.
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

// Connect to the instrument we just discovered.
let connectionResult = try await unify.connectInstrument(serialNumber: instrument.serialNumber)

guard connectionResult == .success else {
    throw UnifyError.connectionFailed(reason: "Result was \(connectionResult)")
}

// Read the connected instrument definition so the test can use settings that are
// valid for the specific hardware model.
guard let instrumentDefinition = try unify.getInstrumentDefinition(serialNumber: instrument.serialNumber).caaInstrumentDefinition else {
    throw UnifyError.instrumentDefinitionNotFound
}

// Define the test you want the instrument to run. This one requests a single
// return loss vs frequency trace across the instrument's supported range.
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
                // `durationS` is the maximum time this measurement is allowed to run.
                durationS: 60,
            ))
    ],
    cardinality: .single
)

// Configure the test before starting the measurement so the SDK can validate it.
let testConfigurationResult = try unify.configureTest(
    test: test
)
guard testConfigurationResult.valid else {
    throw UnifyError.invalidTestConfiguration
}

print("Starting test")

// `runTest()` streams progress updates while the instrument executes the configured test.
for try await progressUpdate in unify.runTest(checkRl: true) {
    let percentage = progressUpdate.traceProgress
    print("Progress: \(percentage * 100)%")
}

print("Test complete!")

// After the test finishes, fetch the batched result and inspect the trace data.
if let testResult = try await unify.getBatchedTestResults().first(where: { _ in true }) {
    print("Got \(testResult.tracePoints.count) points.")
}

// Wrap async work in a timeout so discovery fails explicitly instead of waiting
// forever when no instrument appears.
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
    case instrumentNotFound
    case instrumentDefinitionNotFound
    case invalidTestConfiguration
    case timeout
}
