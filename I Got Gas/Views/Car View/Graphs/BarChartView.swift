//
//  BarChartView.swift
//  I Got Gas
//
//  Created by snow on 10/17/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import Charts

struct BarChartView: View {
    var title: String
    var services: [SDService]
    
    var dataPoints: [(date: Date, mpg: Double, id: String)] {
        let sortedServices = services.sorted(by: { $0.odometer < $1.odometer })
        var points: [(date: Date, mpg: Double, id: String)] = []
        var previousOdometer = sortedServices.first?.odometer ?? 0
        
        for service in sortedServices {
            let currentOdometer = service.odometer
            let milesDriven = currentOdometer - previousOdometer
            
            guard milesDriven > 0, service.gallons > 0 else { continue }
            
            let mpg = Double(milesDriven) / service.gallons
            
            points.append((date: service.date, mpg: mpg, id: UUID().uuidString))
            
            previousOdometer = currentOdometer
        }
        
        return points
    }
    
    var body: some View {
        VStack {
            Text(title)
            if dataPoints.isEmpty {
                Spacer()
                Text("No data yet.")
                Text("Add some expenses!")
                Spacer()
            } else {
                Chart(dataPoints, id: \.id) { point in
                    BarMark(
                        x: .value("Date", DateFormatter.taskDateFormat.string(from: point.date)),
                        y: .value("MPG", point.mpg)
                    )
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .padding(.bottom)
    }
}
