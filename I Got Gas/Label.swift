//
//  Labels.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ImageAndTextLable: View {
    var imageName: String
    var text: String
    var body: some View {
        HStack {
            Image(systemName: "\(imageName)")
            Text("\(text)")
        }
    }
}
