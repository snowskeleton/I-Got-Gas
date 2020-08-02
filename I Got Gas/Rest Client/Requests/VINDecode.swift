//
//  VINDecode.swift
//  I Got Gas
//
//  Created by Michael Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation

public struct DecodeVIN: APIRequest {
    public typealias Response = [VINProperty]
    
    public var resourceName: String {
        return "decodevin/\(vin)"
    }
    // Parameters
    public let format: String?
    public let modelYear: Int?
    public let vin: String
    
    public init(format: String? = "json",
                modelYear: Int? = nil,
                vin: String) {
        self.format = format
        self.modelYear = modelYear
        self.vin = vin
    }
}
