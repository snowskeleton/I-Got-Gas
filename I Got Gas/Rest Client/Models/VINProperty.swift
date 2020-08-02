//
//  VINProperty.swift
//  I Got Gas
//
//  Created by Michael Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation

public struct VINProperty: Decodable {
    public let value: String?
    public let valueId: String?
    public let variable: String
    public let variableId: Int
}
