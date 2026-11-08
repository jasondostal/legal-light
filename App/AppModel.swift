import CoreLocation
import HoursCore
import Observation
import WidgetKit

/// The one piece of state: where you are and what you're hunting. Saved to the
/// App Group so the widgets count down to the same thing.
@Observable
final class AppModel: NSObject, CLLocationManagerDelegate {
    var spot: Spot { didSet { if spot != oldValue { persist() } } }
    /// True until the hunter has picked a spot (GPS or a town).
    private(set) var isDefaultSpot: Bool
    private(set) var locating = false
    private(set) var locationError: String?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        if let s = SharedStore.load() { spot = s; isDefaultSpot = false }
        else { spot = .stevensPoint; isDefaultSpot = true }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var whereabouts: Locate.Where { spot.whereabouts }
    var duckZone: (zone: Locate.DuckZone, km: Double?)? { Locate.duckZone(lat: spot.lat, lon: spot.lon, where: whereabouts) }

    func setRules(_ r: RuleSet) { spot.rules = r }

    func setPlace(_ p: Geo.Place) {
        spot = Spot(lat: p.lat, lon: p.lon, name: p.name, gps: false, rules: spot.rules)
        isDefaultSpot = false
    }

    /// A spot tapped on the map.
    func setCoordinates(lat: Double, lon: Double) {
        let near = Locate.nearestPlace(lat: lat, lon: lon)
        let name = near.map { $0.km < 3 ? $0.place.name : "Near \($0.place.name)" } ?? "Map pin"
        spot = Spot(lat: lat, lon: lon, name: name, gps: false, rules: spot.rules)
        isDefaultSpot = false
    }

    /// One-shot GPS fix. Called from the button, and on launch when the saved
    /// spot came from GPS (you've likely driven somewhere since).
    func locate() {
        locationError = nil
        switch manager.authorizationStatus {
        case .notDetermined: locating = true; manager.requestWhenInUseAuthorization()
        case .denied, .restricted: locationError = "Location is off for Legal Light. Pick a town instead, or allow it in Settings."
        default: locating = true; manager.requestLocation()
        }
    }

    func refreshIfGPS() { if spot.gps && !isDefaultSpot { locate() } }

    private func persist() {
        SharedStore.save(spot)
        WidgetCenter.shared.reloadAllTimelines()
        Alerts.reschedule(spot)
        let s = spot
        Task { await HuntLive.sync(s) }
    }

    /// App came forward: roll alerts forward and bring a running hunt up to date.
    func foreground() {
        refreshIfGPS()
        Alerts.reschedule(spot)
        let s = spot
        Task { await HuntLive.sync(s) }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        guard locating else { return }
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
        case .denied, .restricted:
            locating = false
            locationError = "Location is off for Legal Light. Pick a town instead, or allow it in Settings."
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        locating = false
        let lat = l.coordinate.latitude, lon = l.coordinate.longitude
        let near = Locate.nearestPlace(lat: lat, lon: lon)
        let name = near.map { $0.km < 3 ? $0.place.name : "Near \($0.place.name)" }
        spot = Spot(lat: lat, lon: lon, name: name, gps: true, rules: spot.rules)
        isDefaultSpot = false
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        locating = false
        // A failed refresh keeps the last good fix; only complain if asked.
        if (error as? CLError)?.code != .locationUnknown { locationError = "Couldn't get a fix. Pick a town, or try again with a view of the sky." }
    }
}
