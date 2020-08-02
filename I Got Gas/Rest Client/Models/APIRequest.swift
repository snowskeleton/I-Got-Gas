//
//  APIRequest.swift
//  I Got Gas
//
//  Created by Michael Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
/// All requests must conform to this protocol
/// - Discussion: You must conform to Encodable too, so that all stored public parameters
///   of types conforming this protocol will be encoded as parameters.

public protocol APIRequest: Encodable {

    associatedtype Response: Decodable
    
    var resourceName: String { get }
}
