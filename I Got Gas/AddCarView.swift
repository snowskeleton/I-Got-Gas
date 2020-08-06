//
//  AddCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI

struct AddCarView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    @State private var numA = ["1885", "1886", "1887", "1888", "1889", "1890", "1891", "1892", "1893", "1894", "1895", "1896", "1897", "1898", "1899", "1900", "1901", "1902", "1903", "1904", "1905", "1906", "1907", "1908", "1909", "1910", "1911", "1912", "1913", "1914", "1915", "1916", "1917", "1918", "1919", "1920", "1921", "1922", "1923", "1924", "1925", "1926", "1927", "1928", "1929", "1930", "1931", "1932", "1933", "1934", "1935", "1936", "1937", "1938", "1939", "1940", "1941", "1942", "1943", "1944", "1945", "1946", "1947", "1948", "1949", "1950", "1951", "1952", "1953", "1954", "1955", "1956", "1957", "1958", "1959", "1960", "1961", "1962", "1963", "1964", "1965", "1966", "1967", "1968", "1969", "1970", "1971", "1972", "1973", "1974", "1975", "1976", "1977", "1978", "1979", "1980", "1981", "1982", "1983", "1984", "1985", "1986", "1987", "1988", "1989", "1990", "1991", "1992", "1993", "1994", "1995", "1996", "1997", "1998", "1999", "2000", "2001", "2002", "2003", "2004", "2005", "2006", "2007", "2008", "2009", "2010", "2011", "2012", "2013", "2014", "2015", "2016", "2017", "2018", "2019", "2020", "2021"]

    @Binding var show: Bool
    @State private var buttonEnabled = false

    @State private var carName = ""
    
    @State var carYear = 0
    @State private var showsYearPicker = false

    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer = ""
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info")) {
                            TextField("Name",
                                      text: self.$carName,
                                      onCommit: { self.maybeEnableButton() })

                            CollapsableWheelPicker(
                                    "",
                                    showsPicker: $showsYearPicker,
                                    selection: $carYear
                                ) {
                                    ForEach(0..<self.numA.count) {
                                        Text("\(self.numA[$0])")
                                    }
                                }
                            .animation(.easeInOut)
                            if !self.showsYearPicker {
                                Text(carYear == 0 ? "Year: " : "\(self.numA[carYear])")
                                    .onTapGesture {
                                        self.showsYearPicker.toggle()
                                    }
                            }
                            TextField("* Make",
                                      text: self.$carMake,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* Model",
                                      text: self.$carModel,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* Current Odometer",
                                      text: self.$carOdometer,
                                      onCommit: { self.maybeEnableButton() })
                                .keyboardType(.numberPad)
                            TextField("* License Plate",
                                      text: self.$carPlate,
                                      onCommit: { self.maybeEnableButton() })
                            TextField("* VIN",
                                      text: self.$carVIN,
                                      onCommit: { self.maybeEnableButton() })
                        }
                    }
                }
            .navigationBarTitle("You get a car!")
            }
            
            Spacer()
            
            Button(action: {
                self.save()
            }) {
                Text("Add Vehicle")
            }
        .disabled(!buttonEnabled)
        }
    }

    func maybeEnableButton() {
//        if self.carYear != nil {
//            return
//        }
        if self.carMake == "" {
            return
        }
        if self.carModel == "" {
            return
        }
        if self.carPlate == "" {
            return
        }
        if self.carVIN == "" {
            return
        }
        if self.carOdometer == "" {
            return
        }
        self.buttonEnabled = true
    }
    
    func save() {
        let car = Car(context: self.managedObjectContext)
        car.name = self.carName
//        car.year = self.carYear
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        car.odometer = Int64(self.carOdometer) ?? 0
        car.id = UUID().uuidString
        try? self.managedObjectContext.save()
        
        self.show = false
    }
}

struct AddCarView_Previews: PreviewProvider {
    static var previews: some View {
        AddCarView(show: Binding.constant(true))

    }
}
