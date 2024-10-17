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
    
    var strideLength: Double {
        let totalDistance = services.map { $0.odometer }.max() ?? car.startingOdometer
        let distanceDriven = totalDistance - car.startingOdometer
        
        // Calculate the stride as 10% of the total distance but capped at 250 miles
        return min(Double(distanceDriven) * 0.25, 250)
    }

    var dataPoints: [(odometer: Int, costPerMile: Double)] {
        var points: [(odometer: Int, costPerMile: Double)] = []
        
        let validServices = services.filter {
            !$0.isFuel &&
            $0.odometer > car.startingOdometer
        }
        
        // Step 1: Use a dictionary to accumulate costs by odometer
        var mileageCostDict: [Int: Double] = [:]
        
        for service in validServices {
            let mileage = service.odometer
            mileageCostDict[mileage, default: 0.0] += service.cost
        }
        
        // Step 2: Create data points from the accumulated mileage-cost dictionary
        for (odometer, totalCost) in mileageCostDict.sorted(by: { $0.key < $1.key }) {
            let milesDriven = odometer - car.startingOdometer
            guard milesDriven > 0 else { continue }
            
            let costPerMile = totalCost / Double(milesDriven)
            points.append((odometer: odometer, costPerMile: costPerMile))
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
                AxisMarks(values: .stride(by: strideLength))
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
        .padding(.bottom)
    }
}
