//
//  MaintenanceBoxView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct FutureServiceBoxView: View {
    var futureServicesFetchRequest: FetchRequest<FutureService>
    var futureServices: FetchedResults<FutureService> { futureServicesFetchRequest.wrappedValue }
    
    init(carID: String) {
        futureServicesFetchRequest = FetchFutureServices(howMany: 0, carID: carID)
    }
    
    
    var body: some View {
            GroupBox(label: ImageAndTextLable(image: "clock", text: "Future Service")) {
                VStack(alignment: .leading) {
                    ForEach(futureServices, id: \.self) { futureService in
                        HStack {
                            Text("\(futureService.name!)")
                            Spacer()
                            Text("\(futureService.miles) / \(futureService.date!, formatter: DateFormatter.taskDateFormat)")
                        }
                    }
                }
            }
    }
}
