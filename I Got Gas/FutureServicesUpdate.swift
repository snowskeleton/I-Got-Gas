////
////  FutureServicesUpdate.swift
////  I Got Gas
////
////  Created by Isaac Lyons on 8/15/20.
////  Copyright © 2020 Blizzard Skeleton. All rights reserved.
////
//
//import Foundation
//import SwiftUI
//
//struct Stats {
//    func update(carID: String, odometerReading: Int64) -> Void {
//
//        var carFetchRequest: FetchRequest<Car>
//        var car: FetchedResults<Car> { carFetchRequest.wrappedValue }
//        var futureServicesFetchRequest: FetchRequest<FutureService>
//        var futureServices: FetchedResults<FutureService> { futureServicesFetchRequest.wrappedValue }
//
//        carFetchRequest = Fetch.car(carID: carID)
//
//        futureServicesFetchRequest = Fetch.futureServices(howMany: 0, carID: carID)
//
//        for car in car {
//            for futureService in futureServices {
//                if futureService.startingMiles != 0 {
//
//                    futureService.milesLeft -= ( car.odometer - odometerReading)
//
//                    if futureService.milesLeft <= 0 {
//                        futureService.important = true
//                    }
//
//                    if futureService.date! < Date() {
//                        futureService.important = true
//                    }
//
//                }
//            }
//        }
//    }
//}
