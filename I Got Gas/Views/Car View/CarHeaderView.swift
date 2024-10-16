//
//  CarHeaderView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/11/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct CarHeaderView: View {
    @Binding var car: SDCar
    @State private var priceFormat = UserDefaults.standard.string(forKey: "priceFormat") ?? ""
    
    @Query var services: [SDService]
    
    var dataPoints: [(odometer: Int, costPerMile: Double)] {
        var points: [(odometer: Int, costPerMile: Double)] = []
        
        // Filter services with valid odometer readings
        let validServices = services.filter { $0.odometer > car.startingOdometer && ($0.dateCompleted == nil || ($0.dateCompleted != nil && !$0.pendingCompletion)) }
        
        // Loop through valid services, calculating cost per mile for each individual service
        for service in validServices.sorted(by: { $0.odometer < $1.odometer }) {
            let milesDriven = service.odometer - car.startingOdometer
            guard milesDriven > 0 else { continue } // Avoid division by zero
            
            let costPerMile = service.cost / Double(milesDriven) // Calculate cost per mile for this specific service
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
            Chart(dataPoints, id: \.odometer) { point in
                LineMark(
                    x: .value("Odometer", point.odometer),
                    y: .value("Cost per Mile", point.costPerMile)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 500)) // Adjust stride to your needs
            }
            .chartXScale(domain: car.startingOdometer...(dataPoints.map { $0.odometer }.max() ?? car.startingOdometer)) // Set minimum and maximum range
            .chartYAxis {
                AxisMarks { value in
                    if let costPerMile = value.as(Double.self) {
                        AxisValueLabel {
                            Text(costPerMile, format: .currency(code: "USD")) // Format as currency
                        }
                    }
                }
            }

            .padding()
        }
        .padding()

//        VStack {
//            HStack {
//                Spacer()
//                
//                VStack {
//                    Text("Cost/Mile")
//                        .font(.system(size: 10))
//                    Text("$\(car.costPerMile, specifier: priceFormat)")
//                }.padding(.leading)
//                
//                Spacer()
//                
//                VStack {
//                    Text("Cost/Gal")
//                        .font(.system(size: 10))
//                    Text("$\(car.costPerGallon, specifier: priceFormat)")
//                }
//                Spacer()
//                
//            }
//            .padding(.top)
//            .font(.largeTitle)
//
//            Text("\(car.odometer)")
//        }
    }
}
