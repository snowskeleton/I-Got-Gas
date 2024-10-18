//
//  LineChartView.swift
//  I Got Gas
//
//  Created by snow on 10/17/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import Charts

struct LineChartView: View {
    var title: String
    var services: [SDService]

    var rangeStart: Int {
        services.map { $0.odometer }.min() ?? 0
    }
    
    var rangeEnd: Int {
        services.map { $0.odometer }.max() ?? 0
    }

    var strideLength: Double {
        let totalDistance = dataPoints.map { $0.odometer }.max() ?? rangeStart
        let distanceDriven = totalDistance - rangeStart
        return min(Double(distanceDriven) * 0.25, 250)
    }
    
    var dataPoints: [(odometer: Int, costPerMile: Double)] {
        var points: [(odometer: Int, costPerMile: Double)] = []
        var mileageCostDict: [Int: Double] = [:]
        
        for service in services {
            let mileage = service.odometer
            mileageCostDict[mileage, default: 0.0] += service.cost
        }
        
        for (odometer, totalCost) in mileageCostDict.sorted(by: { $0.key < $1.key }) {
            let milesDriven = odometer - rangeStart
            guard milesDriven > 0 else {
                continue
            }
            
            let costPerMile = totalCost / Double(milesDriven)
            points.append((odometer: odometer, costPerMile: costPerMile))
        }
        
        return points
    }


    var body: some View {
        VStack {
            Text(title)
            if dataPoints.count < 2 {
                Spacer()
                Text("Not enough data yet.")
                Text("Add some expenses!")
                Spacer()
            } else {
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
                .chartXScale(domain: rangeStart...rangeEnd)
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
        }
        .padding()
        .padding(.bottom)
    }
}
