//
//  SwiftUIView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct CarView: View {
    
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .padding(.leading)
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("Vehicle name")
                Text("Make, modle, year")
                Text("Some number stats")
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color.blue)
        .opacity(0.8)
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }
}

struct CarView_Previews: PreviewProvider {
    static var previews: some View {
        CarView()
    }
}
