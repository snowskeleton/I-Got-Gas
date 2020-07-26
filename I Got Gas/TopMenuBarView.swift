//
//  TopMenuBar.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct TopMenuBarView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    @State var showAddCarView = false
    
    var body: some View {
        HStack {
            
        Button(action: {
            self.showAddCarView.toggle()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 30))
        }.padding(.leading)
            .sheet(isPresented: $showAddCarView) {
                AddCarView(show: self.$showAddCarView).environment(\.managedObjectContext, self.managedObjectContext)
        }
        Spacer()
        
        Spacer()
        
        Button(action: {
            //
        }) {
            Text("Options")
        }.padding(.trailing)
        }
    }
}

struct TopMenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        TopMenuBarView()
    }
}
