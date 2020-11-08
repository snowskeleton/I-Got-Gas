//
//  Version Number.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 11/8/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
import UIKit

extension UIApplication {
    static var appVersion: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
