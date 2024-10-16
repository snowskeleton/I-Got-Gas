//
//  MaintenenceChart90DayView.swift
//  I Got Gas
//
//  Created by snow on 10/16/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct MaintenenceChart90DayView: View {
    @Binding var car: SDCar
    @AppStorage("priceFormat") var priceFormat = "%.3f"
    
    @State private var selectedTab = "Default"
    
    @Query var services: [SDService]
    
    var dataPoints: [(odometer: Int, costPerMile: Double)] {
        var points: [(odometer: Int, costPerMile: Double)] = []
        
        let validServices = services.filter {
            !$0.isFuel &&
            $0.odometer > car.startingOdometer &&
            ($0.dateCompleted == nil || ($0.dateCompleted != nil && !$0.pendingCompletion))
        }

        for service in validServices.sorted(by: { $0.odometer < $1.odometer }) {
            let milesDriven = service.odometer - car.startingOdometer
            guard milesDriven > 0 else { continue }
            
            let costPerMile = service.cost / Double(milesDriven)
            points.append((odometer: service.odometer, costPerMile: costPerMile))
        }
        return points
    }
    
    init(car: Binding<SDCar>) {
        self._car = car
        let carId = car.wrappedValue.localId
        let predicate = #Predicate<SDService> { $0.car?.localId == carId }
        let descriptor = FetchDescriptor<SDService>(predicate: predicate, sortBy: [SortDescriptor(\.odometer)])
        _services = Query(descriptor)
    }
    
    var body: some View {
        VStack {
            Text("Maintenence Expenses")
            Chart(dataPoints, id: \.odometer) { point in
                LineMark(
                    x: .value("Odometer", point.odometer),
                    y: .value("Cost per Mile", point.costPerMile)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 500))
            }
            .chartXScale(domain: car.startingOdometer...(dataPoints.map { $0.odometer }.max() ?? car.startingOdometer))
            .chartYAxis {
                AxisMarks { value in
                    if let costPerMile = value.as(Double.self) {
                        AxisValueLabel {
                            Text(costPerMile, format: .currency(code: "USD"))
                        }
                    }
                }
            }
        }
        .padding()
    }
}
