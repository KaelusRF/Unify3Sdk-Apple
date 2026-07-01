import Foundation
import PDFKit
import SwiftUI
import Unify3Sdk

struct ReturnLossExampleView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var model = ReturnLossExampleModel()

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

        Button("3) Run Return Loss Test") {
          model.runReturnLossTest()
        }
        .buttonStyle(.borderedProminent)

        Button("4) Create and Show Report PDF") {
          model.createAndShowReportPdf()
        }
        .buttonStyle(.borderedProminent)

        ExampleStatusView(progress: model.progress, status: model.status)
      }
      .padding()
    }
    .navigationTitle("Return Loss Test")
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
    .sheet(item: $model.reportPdf) { reportPdf in
      NavigationStack {
        ReportPDFView(url: reportPdf.url)
          .navigationTitle("Report PDF")
          .navigationBarTitleDisplayMode(.inline)
      }
    }
  }
}

@MainActor
final class ReturnLossExampleModel: ObservableObject {
  @Published var progress = ExampleProgress.hidden
  @Published var reportPdf: ReportPDF?
  @Published var status = ""

  private let unify = Unify.shared
  private var discoveredInstrument: Instrument?
  private var connectedSerialNumber: String?
  private var latestTraceId: Int64?
  private var logTask: Task<Void, Never>?

  init() {
    do {
      try unify.setLogLevels(minLevel: .info, maxLevel: .error)
      appendStatus("Return Loss Test example")
      appendStatus("Flow: Discover -> Connect -> Run Test")
    } catch {
      appendStatus("Set log levels failed: \(error.localizedDescription)")
    }
  }

  deinit {
    logTask?.cancel()
  }

  func startLogStream() {
    guard logTask == nil else { return }

    let unify = unify
    logTask = Task { [weak self] in
      do {
        // Logs are useful while learning the SDK, so the example displays them
        // in the same status area as the button-driven workflow messages.
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

  func runReturnLossTest() {
    clearStatus()

    Task { [weak self] in
      guard let self else { return }

      do {
        guard let serialNumber = connectedSerialNumber else {
          throw ExampleError.connectFirst
        }

        let (instrumentDefinition, traceConfiguration) = try configureReturnLossFrequencyTrace(
          using: unify,
          serialNumber: serialNumber
        )
        guard let traceId = traceConfiguration.trace.id else {
          throw ExampleError.missingTraceId
        }

        appendStatus(
          "Configured return loss trace for \(instrumentDefinition.model) "
            + "(\(traceConfiguration.trace.frequencyRangeHz.start)..\(traceConfiguration.trace.frequencyRangeHz.end) Hz)"
        )

        let unify = self.unify
        var lastReportedPercent = -1
        appendStatus("Running test...")

        // runTest() streams progress while the instrument performs the trace.
        for try await progressUpdate in unify.runTest(checkRl: true) {
          if progressUpdate.traceProgress < 0 {
            progress = .indeterminate
            lastReportedPercent = Int.min
          } else {
            let percent = Int((progressUpdate.traceProgress * 100).rounded()).clamped(to: 0...100)
            if percent != lastReportedPercent {
              progress = .percent(percent)
              lastReportedPercent = percent
            }
          }
        }

        guard let result = try await unify.getBatchedTestResults().first(where: { _ in true }) else {
          throw ExampleError.noBatchedResult
        }

        progress = .hidden
        latestTraceId = traceId
        appendStatus("Test complete. Trace \(result.traceIndex) returned \(result.tracePoints.count) points")
      } catch {
        progress = .hidden
        appendStatus("Run test failed: \(error.localizedDescription)")
      }
    }
  }

  func createAndShowReportPdf() {
    Task { [weak self] in
      guard let self else { return }

      do {
        guard let traceId = latestTraceId else {
          throw ExampleError.runTestFirst
        }

        // Create a new report, add the measured trace, then print the report
        // to a PDF file.
        try unify.newReport()
        try unify.recordTrace(traceId: traceId, tags: [], comment: "", location: nil)

        let reportUrl = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension("pdf")
        try unify.printReportToPdf(filePath: reportUrl.path, orientation: .portrait)

        reportPdf = ReportPDF(url: reportUrl)
        appendStatus("Created report PDF: \(reportUrl.lastPathComponent)")
      } catch {
        appendStatus("Create report failed: \(error.localizedDescription)")
      }
    }
  }

  func disconnectIfNeeded() async {
    guard let serialNumber = connectedSerialNumber else { return }
    connectedSerialNumber = nil

    await disconnectConnectedInstrument(
      using: unify,
      serialNumber: serialNumber,
      appendStatus: appendStatus
    )
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

struct ReportPDF: Identifiable {
  let id = UUID()
  let url: URL
}

struct ReportPDFView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> PDFView {
    let pdfView = PDFView()
    pdfView.autoScales = true
    return pdfView
  }

  func updateUIView(_ pdfView: PDFView, context: Context) {
    pdfView.document = PDFDocument(url: url)
  }
}
