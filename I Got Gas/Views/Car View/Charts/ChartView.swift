//
//  ChartView.swift
//  I Got Gas
//
//  Created by snow on 10/17/24.
//  Copyright © 2024 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import Charts

struct ChartView: View {
    var title: String
    var services: [SDService]
    var isCurrency: Bool
    var dataPoints: [(date: Date, value: Double, id: String)]
    var average: Double {
        dataPoints.count > 0 ? dataPoints.reduce(0) { $0 + $1.value } / Double(dataPoints.count) : 0
    }
    
    init(title: String, services: [SDService], isCurrency: Bool) {
        self.title = title
        self.services = services
        self.dataPoints = []
        self.isCurrency = isCurrency
    }
    
    init(title: String, mpg services: [SDService], isCurrency: Bool) {
        self.init(title: title, services: services, isCurrency: false)
        
        let sortedServices = services.sorted(by: { $0.odometer < $1.odometer })
        var points: [(date: Date, value: Double, id: String)] = []
        var previousOdometer = sortedServices.first?.odometer ?? 0
        
        for service in sortedServices {
            let currentOdometer = service.odometer
            let milesDriven = currentOdometer - previousOdometer
            
            guard milesDriven > 0, service.gallons > 0 else { continue }
            
            let mpg = Double(milesDriven) / service.gallons
            
            points.append((date: service.date, value: mpg, id: UUID().uuidString))
            
            previousOdometer = currentOdometer
        }
        
        self.dataPoints = points
    }
    
    init(title: String, costs services: [SDService], isCurrency: Bool) {
        self.init(title: title, services: services, isCurrency: true)

        var rangeStart: Int {
            services.map { $0.odometer }.min() ?? 0
        }

        var points: [(date: Date, value: Double, id: String)] = []
        var mileageCostDict: [Int: (cost: Double, date: Date)] = [:]
            
        for service in services {
            let mileage = service.odometer
            mileageCostDict[
                mileage,
                default: (0.0, service.date)
            ].cost += service.cost
        }
            
        for (odometer, data) in mileageCostDict
            .sorted(by: { $0.key < $1.key }) {
            let milesDriven = odometer - rangeStart
            guard milesDriven > 0 else { continue }
                
            let costPerMile = data.cost / Double(milesDriven)
            points.append(
                (date: data.date, value: costPerMile, id: UUID().uuidString)
                )
        }
            
        self.dataPoints = points
    }

    var body: some View {
        VStack {
            HStack {
                Text(title)
                if isCurrency {
                    Text(services.costPerMile, format: .currency(code: "USD"))
                } else {
                    Text("\(average, specifier: "%.2f")")
                }
            }
            if dataPoints.isEmpty {
                Spacer()
                Text("Not enough data yet.")
                Text("Add some expenses!")
                Spacer()
            } else {
                Chart(dataPoints, id: \.id) { point in
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
                                    Text(yValue, format: .currency(code: "USD"))
                                } else {
                                    Text(Int(yValue).description)
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
