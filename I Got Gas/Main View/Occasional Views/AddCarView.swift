//
//  AddCarView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 7/26/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import UIKit

struct AddCarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: Car.entity(), sortDescriptors: []) var cars: FetchedResults<Car>
    
    @State private var buttonEnabled = false
    
    @State private var carYear: String = ""
    
    @State private var carMake = ""
    @State private var carModel = ""
    @State private var carPlate = ""
    @State private var carVIN = ""
    @State private var carOdometer = ""
    
    @State private var somethingorother = ""
    
    var years = yearsPlusTwo()
    @State var selectionIndex = 0
    
    var body: some View {
        VStack {
            NavigationView {
                VStack {
                    Form {
                        Section(header: Text("Vehicle Info"), footer: Text("\nFor the most accurate results, it's recommended to only add a new car when it has a full tank of gas.")) {
                            
                            TextFieldWithPickerAsInputView(data: self.years,
                                                           placeholder: "* Year",
                                                           selectionIndex: self.$selectionIndex,
                                                           text: self.$carYear)
                                .onChange(of: self.carYear) { _ in
                                    self.maybeEnableButton()
                                }
                            
                            TextField("* Make",
                                      text: self.$carMake)
                                .onChange(of: self.carMake, onCommit: {
                                    self.maybeEnableButton()
                                }) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* Model",
                                      text: self.$carModel, onCommit: {
                                        self.maybeEnableButton()
                                      })
                                .onChange(of: self.carModel) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* Current Odometer",
                                      text: self.$carOdometer, onCommit: {
                                        self.maybeEnableButton()
                                      })
                                .keyboardType(.numberPad)
                                .onChange(of: self.carOdometer) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* License Plate",
                                      text: self.$carPlate, onCommit: {
                                        self.maybeEnableButton()
                                      })
                                .disableAutocorrection(true)
                                .onChange(of: self.carPlate) { _ in
                                    self.maybeEnableButton()
                                }

                            TextField("* VIN",
                                      text: self.$carVIN, onCommit: {
                                        self.maybeEnableButton()
                                      })
                                .disableAutocorrection(true)
                                .onChange(of: self.carVIN) { _ in
                                    self.maybeEnableButton()
                                }
                        }
                        
                        Section {
                            Button(action: {
                                self.save()
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Save Vehicle")
                            }
                            .disabled(!buttonEnabled)
                        }
                    }
                    .dismissKeyboardOnSwipe()
                    .dismissKeyboardOnTap()
                }
                .navigationBarTitle("Add Car")
            }
        }
    }
    
    func maybeEnableButton() {
        if self.carYear == "" {
            self.buttonEnabled = false
            return
        }
        if self.carMake == "" {
            self.buttonEnabled = false
            return
        }
        if self.carModel == "" {
            self.buttonEnabled = false
            return
        }
        if self.carOdometer == "" {
            self.buttonEnabled = false
            return
        }
        self.buttonEnabled = true
    }
    
    func save() {
        let car = Car(context: self.moc)
        car.year = self.carYear
        car.make = self.carMake
        car.model = self.carModel
        car.plate = self.carPlate
        car.vin = self.carVIN
        car.odometer = Int64(self.carOdometer)!
        car.startingOdometer = Int64(self.carOdometer)!
        car.id = UUID().uuidString
        try? self.moc.save()        
    }
}


struct TextFieldWithPickerAsInputView : UIViewRepresentable {
    
    var data: [String]
    var placeholder: String
    
    @Binding var selectionIndex: Int
    @Binding var text: String
    
    private let textField = UITextField()
    private let picker = UIPickerView()
    
    func makeCoordinator() -> TextFieldWithPickerAsInputView.Coordinator {
        Coordinator(textfield: self)
    }
    
    func makeUIView(context: UIViewRepresentableContext<TextFieldWithPickerAsInputView>) -> UITextField {
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        textField.placeholder = placeholder
        textField.inputView = picker
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<TextFieldWithPickerAsInputView>) {
        uiView.text = text
    }
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate , UITextFieldDelegate {
        
        private let parent : TextFieldWithPickerAsInputView
        
        init(textfield : TextFieldWithPickerAsInputView) {
            self.parent = textfield
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return self.parent.data.count
        }
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            return self.parent.data[row]
        }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            self.parent.$selectionIndex.wrappedValue = row
            self.parent.text = self.parent.data[self.parent.selectionIndex]
            self.parent.textField.endEditing(true)
            
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            self.parent.textField.resignFirstResponder()
        }
    }
}
