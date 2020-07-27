//
//  VehicleAPIClient.swift
//  I Got Gas
//
//  Created by Michael Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation

public class VehicleAPIClient {
    private let baseEndpointURL = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles")
    private let session = URLSession(configuration: .default)
    
}
