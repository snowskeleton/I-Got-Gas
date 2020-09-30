//
//  YearsPlusTwo.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import Foundation
import SwiftUI

func yearsPlusTwo() -> [String] { //you're gonna want to move this into AddCarView, since that's the only place this is used. Don't do it. Something about initializing before use, or something.
    var list: [Int] = []
    
    var upperRange: Int {
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy"
        let formattedDate = format.string(from: date)
        let plusTwo = Int(formattedDate)! + 2
        return plusTwo
    }
    
    for i in 1885...upperRange {
        list.insert(i, at: 0)
    }
    
    let returnlist = list.map { String($0) }
    return returnlist
}
