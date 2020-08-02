//
//  NHTSAResponse.swift
//  I Got Gas
//
//  Created by Michael Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation

public struct NHTSAResponse<Response: Decodable>: Decodable {
    public let count: Int?
    public let message: String?
    public let searchCriteria: String?
    public let results: ResultsContainer<Response>?
}
