import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text("Unify 3 SDK Examples")
          .font(.title)
          .bold()

        Text("Choose an example workflow:")

        NavigationLink("Return Loss Test Example") {
          ReturnLossExampleView()
        }
        .buttonStyle(.borderedProminent)

        NavigationLink("OSL Calibration Example") {
          OslCalibrationExampleView()
        }
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .padding()
      .navigationTitle("Examples")
    }
  }
}

#Preview {
  ContentView()
}
