import SwiftUI
import HoursCore

struct LocationSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var askedGPS = false

    private var places: [Geo.Place] {
        let all = Bundled.geo.places
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.county.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { askedGPS = true; model.locate() } label: {
                        HStack {
                            Label("Use my location", systemImage: "location.fill").foregroundStyle(Theme.mallard)
                            Spacer()
                            if model.locating { ProgressView() }
                        }
                    }
                    if let e = model.locationError { Text(e).font(.footnote).foregroundStyle(Theme.lantern) }
                } footer: {
                    Text("Works with no signal: GPS doesn't need a cell connection, and everything else is on the phone.")
                }
                Section("Towns") {
                    ForEach(places) { p in
                        Button { model.setPlace(p); dismiss() } label: {
                            HStack {
                                Text(p.name).foregroundStyle(Theme.bone)
                                Spacer()
                                Text("\(p.county) Co.").foregroundStyle(Theme.reed)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
            .font(.mono(15))
            .searchable(text: $query, prompt: "Town or county")
            .navigationTitle("Your spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(Theme.mallard) } }
            .onChange(of: model.locating) { was, now in
                if askedGPS && was && !now && model.locationError == nil { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }
}
