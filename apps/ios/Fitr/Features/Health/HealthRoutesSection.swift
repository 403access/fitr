import MapKit
import SwiftUI

/// Movement map and GPS history.
///
/// iOS has no system-wide location history. HealthKit only stores a route when
/// an app records a workout (Apple Watch outdoor workouts, Strava, Garmin…),
/// so this view does two things:
/// 1. imports every workout route Apple Health already has;
/// 2. offers an opt-in local recorder that builds day-long history from now on.
struct HealthRoutesSection: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Binding var range: HealthRange

    private var health: HealthStore { store.health }
    private var recorder: RouteRecorder { store.routeRecorder }
    private var routes: [HealthRoute] { health.routeHistory }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            rangePicker
            recordingCard

            if health.isLoadingRoutes && routes.isEmpty {
                loadingState
            } else if routes.isEmpty {
                emptyState
            } else {
                mapCard
                routeList
            }

            sourceNote
        }
        .onChange(of: recorder.lastPointAt) { _, _ in
            health.refreshLocalRoutes(range: range)
        }
    }

    // MARK: - Range

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(HealthRange.allCases) { item in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.snappy(duration: 0.2)) { range = item }
                } label: {
                    Text(item.title)
                        .font(Theme.font(10, .bold))
                        .foregroundStyle(range == item ? Theme.ink : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if range == item {
                                Capsule().fill(Theme.violet)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    // MARK: - Recording

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Theme.lime.opacity(0.14) : Theme.inkSoft)
                        .frame(width: 42, height: 42)
                    Image(systemName: recorder.isRecording ? "location.fill" : "location.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(recorder.isRecording ? Theme.lime : Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(recorder.isRecording ? "Recording movement" : "Record movement")
                            .font(Theme.font(14, .bold))
                            .foregroundStyle(Theme.text)
                        if recorder.isRecording {
                            Circle()
                                .fill(Theme.lime)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(recorder.statusLabel)
                        .font(Theme.font(10, .medium))
                        .foregroundStyle(recorder.isAuthorized ? Theme.mint : Theme.textTertiary)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: recordingBinding)
                    .labelsHidden()
                    .tint(Theme.lime)
            }

            Text(recordingExplanation)
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)

            HStack(spacing: 8) {
                recordingStat(value: "\(recorder.todayPointCount)", label: "points today", tint: Theme.lime)
                recordingStat(value: "\(recorder.recordedRouteCount)", label: "segments kept", tint: Theme.sky)
                Spacer(minLength: 0)
            }

            if let error = recorder.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.coral)
                        .padding(.top, 1)
                    Text(error)
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(2)
                    Spacer(minLength: 0)
                }
            }

            if recorder.authorizationStatus == .denied || recorder.authorizationStatus == .restricted {
                Button("Open Location Settings") {
                    openLocationSettings()
                }
                .font(Theme.font(11, .bold))
                .foregroundStyle(Theme.coral)
                .buttonStyle(.plain)
            } else if recorder.authorizationStatus == .notDetermined && !settings.recordGPSHistory {
                Button("Enable location recording") {
                    recorder.requestAccess()
                }
                .buttonStyle(FitrPrimaryButtonStyle(tint: Theme.lime))
            } else if recorder.authorizationStatus == .authorizedWhenInUse {
                Button {
                    recorder.requestBackgroundAccess()
                } label: {
                    Label("Allow background recording", systemImage: "arrow.up.forward.app.fill")
                        .font(Theme.font(11, .bold))
                }
                .foregroundStyle(Theme.mint)
                .buttonStyle(.plain)
            }
        }
        .fitrCard()
    }

    private var recordingBinding: Binding<Bool> {
        Binding(
            get: { settings.recordGPSHistory },
            set: { recorder.setEnabled($0) }
        )
    }

    private var recordingExplanation: String {
        if !settings.recordGPSHistory {
            return "Apple Health only keeps GPS inside workouts. Turn this on to build a day-long local trail that powers the map below."
        }
        switch recorder.authorizationStatus {
        case .authorizedAlways:
            return "On, including in the background. Samples stay in this iPhone's app storage and are pruned after \(RouteArchive.retentionDays) days."
        case .authorizedWhenInUse:
            return "On while Fitr is open. Choose Always in Settings for movement that continues through the day."
        case .denied, .restricted:
            return "Location permission is off, so no new movement is being recorded. Existing Apple Health workout routes still appear below."
        case .notDetermined:
            return "Location permission is needed before Fitr can record a trail."
        @unknown default:
            return "Waiting for location permission."
        }
    }

    private func recordingStat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.mono(12, .bold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.inkSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle().fill(tint).frame(width: 4, height: 4).padding(7)
        }
    }

    // MARK: - Map

    private var mapCard: some View {
        let totalDistance = routes.reduce(0) { $0 + $1.distanceMeters }
        let totalMinutes = routes.reduce(0) { $0 + $1.durationMinutes }
        let healthRoutes = routes.filter { $0.source == .healthKit }.count
        let deviceRoutes = routes.count - healthRoutes

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Movement map", subtitle: "\(range.subtitle) · \(routes.count) route\(routes.count == 1 ? "" : "s")") {
                FitrPill(
                    text: "\(HealthFormatting.distance(totalDistance)) km",
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: Theme.sky
                )
            }

            RouteMapView(routes: routes)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                )

            HStack(spacing: 8) {
                mapStat(value: "\(Int(totalMinutes.rounded()))", label: "active min", tint: Theme.lime)
                mapStat(value: "\(healthRoutes)", label: "from Health", tint: Theme.coral)
                mapStat(value: "\(deviceRoutes)", label: "on this iPhone", tint: Theme.sky)
            }

            HStack(spacing: 14) {
                legendDot(color: Theme.coral, text: "Health workouts")
                legendDot(color: Theme.lime, text: "device trail")
                Spacer()
            }
        }
        .fitrCard()
    }

    private func mapStat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.font(17, .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text(label)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.surface.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle().fill(tint).frame(width: 4, height: 4).padding(8)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(Theme.font(8))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - List

    private var groupedRoutes: [RouteDayGroup] {
        Dictionary(grouping: routes) { FitrDate.calendar.startOfDay(for: $0.start) }
            .map { RouteDayGroup(day: $0.key, routes: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.day > $1.day }
    }

    private var routeList: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading("Routes", subtitle: "Every route in this range")

            ForEach(groupedRoutes) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(HealthFormatting.relativeDay(group.day))
                        .font(Theme.font(10, .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.textTertiary)
                        .textCase(.uppercase)

                    VStack(spacing: 0) {
                        ForEach(Array(group.routes.enumerated()), id: \.element.id) { index, route in
                            routeRow(route)
                            if index < group.routes.count - 1 {
                                Divider().overlay(Theme.stroke)
                            }
                        }
                    }
                    .fitrCard(padding: 4)
                }
            }
        }
    }

    private func routeRow(_ route: HealthRoute) -> some View {
        let tint = route.source == .healthKit ? Theme.coral : Theme.lime
        return HStack(spacing: 12) {
            Image(systemName: route.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.10)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(route.activityName)
                        .font(Theme.font(12, .semibold))
                        .foregroundStyle(Theme.text)
                    Text(route.source == .healthKit ? "HEALTH" : "LIVE")
                        .font(Theme.font(7, .heavy))
                        .tracking(0.8)
                        .foregroundStyle(route.source == .healthKit ? Theme.coral : Theme.ink)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(route.source == .healthKit ? Theme.coral.opacity(0.14) : Theme.lime))
                }
                Text("\(timeRange(route)) · \(route.sourceName)")
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(HealthFormatting.distance(route.distanceMeters)) km")
                    .font(Theme.mono(9, .bold))
                    .foregroundStyle(Theme.text)
                Text(FitrDate.minutes(route.durationMinutes))
                    .font(Theme.font(8))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func timeRange(_ route: HealthRoute) -> String {
        let start = route.start.formatted(date: .omitted, time: .shortened)
        let end = route.end.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.sky)
            Text("Importing workout routes…")
                .font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var emptyState: some View {
        EmptyPanel(
            icon: "map",
            title: "No GPS routes yet",
            message: "Apple Health only stores GPS for workouts recorded by Apple Watch or outdoor apps like Strava and Garmin. Fitr imports those routes and can record your own day-long movement from now on.",
            actionTitle: settings.recordGPSHistory ? "Refresh routes" : "Enable recording"
        ) {
            if settings.recordGPSHistory {
                Task { await health.loadRoutes(range: range, force: true) }
            } else {
                recorder.setEnabled(true)
            }
        }
    }

    private var sourceNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.mint)
                .padding(.top, 1)
            Text("Imported routes come from Apple Health workouts. Recorded trails are stored only on this iPhone and never sent to your Fitr server. Continuous recording uses more battery; Fitr samples roughly every 30 metres.")
                .font(Theme.font(9))
                .foregroundStyle(Theme.textTertiary)
                .lineSpacing(2)
        }
        .padding(.top, 2)
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct RouteDayGroup: Identifiable {
    var id: Date { day }
    let day: Date
    let routes: [HealthRoute]
}

// MARK: - Map

private struct RouteMapView: View {
    let routes: [HealthRoute]

    @State private var position: MapCameraPosition = .automatic

    private var routeIDs: String {
        routes.map(\.id).joined(separator: "|")
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                let tint = tint(for: index, route: route)
                MapPolyline(coordinates: route.coordinates)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                if routes.count <= 40 {
                    if let first = route.coordinates.first {
                        Annotation("", coordinate: first) {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)
                                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1.5))
                        }
                        .annotationTitles(.hidden)
                    }

                    if let last = route.coordinates.last {
                        Annotation("", coordinate: last) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(tint))
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onAppear { position = .automatic }
        .id(routeIDs)
    }

    private func tint(for index: Int, route: HealthRoute) -> Color {
        if route.source == .device { return Theme.lime }
        let palette = [Theme.coral, Theme.sky, Theme.violet, Theme.pink, Theme.mint]
        return palette[index % palette.count]
    }
}
