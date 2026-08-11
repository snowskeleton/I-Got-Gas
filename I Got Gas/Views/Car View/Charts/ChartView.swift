//
//  ChartView.swift
//  I Got Gas
//
//  Created by snow on 10/17/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import Charts

/// Swift Charts requires `Plottable`, which neither `Money` nor `Decimal`
/// conform to. So aggregation happens in exact types and converts to `Double`
/// at this boundary only — nothing upstream of here does floating-point money.
struct ChartView: View {

    private enum Metric {
        case fuelEconomy(FuelEconomyStyle, label: String)
        case currency
    }

    private struct Point: Identifiable {
        let id = UUID().uuidString
        let date: Date
        let value: Double
    }

    private let title: String
    private let metric: Metric
    private let points: [Point]
    private let summary: String?

    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    private var isCurrency: Bool {
        if case .currency = metric { return true }
        return false
    }

    // MARK: - Fuel economy

    init(economyOf services: [SDService], car: SDCar) {
        let distanceUnit = car.distanceUnit
        let volumeUnit = UnitPreferences.volumeUnit
        let style = FuelEconomyStyle.preferred(distance: distanceUnit, volume: volumeUnit)

        let sorted = services
            .filter { $0.kind == .fuel && !$0.deleted }
            .sorted { $0.odometerMeters < $1.odometerMeters }

        var points: [Point] = []
        var previousOdometer = sorted.first?.odometerMeters ?? 0

        for service in sorted {
            let driven = Distance(meters: service.odometerMeters - previousOdometer)
            defer { previousOdometer = service.odometerMeters }

            guard let economy = FuelEconomy(distance: driven, volume: service.volume) else {
                continue
            }
            points.append(Point(
                date: service.date,
                value: economy.value(distance: distanceUnit, volume: volumeUnit, style: style)
            ))
        }

        let label = FuelEconomy(metersPerMilliliter: 0)
            .label(distance: distanceUnit, volume: volumeUnit, style: style)

        self.title = label
        self.metric = .fuelEconomy(style, label: label)
        self.points = points
        self.summary = points.isEmpty
            ? nil
            : (points.reduce(0) { $0 + $1.value } / Double(points.count))
                .formatted(.number.precision(.fractionLength(1)))
    }

    // MARK: - Cost per distance

    init(costsOf services: [SDService], car: SDCar) {
        let distanceUnit = car.distanceUnit
        let live = services.filter { !$0.deleted }

        // Running cost-per-distance measured from the earliest reading in range.
        let rangeStart = live.map(\.odometerMeters).min() ?? 0

        var costByOdometer: [Int: (minor: Int, date: Date)] = [:]
        for service in live {
            costByOdometer[service.odometerMeters, default: (0, service.date)].minor
                += service.costMinor
        }

        var points: [Point] = []
        for (odometer, data) in costByOdometer.sorted(by: { $0.key < $1.key }) {
            let metersDriven = odometer - rangeStart
            guard metersDriven > 0 else { continue }
            let perUnit = Double(data.minor) / Double(metersDriven) * distanceUnit.metersPerUnit
            points.append(Point(
                date: data.date,
                value: perUnit / pow(10.0, Double(Money.fractionDigits(for: UnitPreferences.currencyCode)))
            ))
        }

        self.title = "Cost per \(distanceUnit.perUnitAbbreviation)"
        self.metric = .currency
        self.points = points
        self.summary = live.costPerDistance(in: distanceUnit)?.formatted()
    }

    // MARK: - Body

    var body: some View {
        VStack {
            HStack {
                Text(title)
                if let summary {
                    Text(summary)
                }
            }
            if points.isEmpty {
                Spacer()
                Text("Not enough data yet.")
                Text("Add some expenses!")
                Spacer()
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value(title, point.value)
                    )
                }
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let yValue = value.as(Double.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                if isCurrency {
                                    Text(Decimal(yValue), format: .currency(
                                        code: UnitPreferences.currencyCode
                                    ))
                                } else {
                                    Text(yValue.formatted(.number.precision(.fractionLength(0))))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .padding(.bottom)
    }
}
