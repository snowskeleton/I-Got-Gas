//
//  Labels.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 8/7/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct ImageAndTextLable: View {
    var systemImage: String? = nil
    var image: String? = nil
    var text: String
    
    var body: some View {
        if systemImage != nil {
            HStack {
                Image(systemName: "\(systemImage!)")
                Text("\(text)")
            }
        } else if image != nil {
            HStack {
                Image(image!)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("\(text)")
            }
        }
    }
}
