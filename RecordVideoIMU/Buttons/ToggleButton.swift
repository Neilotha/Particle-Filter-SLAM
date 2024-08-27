//
//  toggleButton.swift
//  RecordVideoIMU
//
//  Created by Joshua Yang on 2023/6/13.
//

import SwiftUI


struct ToggleButton: View {
    @Binding var inCalibrationMode: Bool
    
    var body: some View {
        Button(action: {
            inCalibrationMode.toggle()
            print(inCalibrationMode)
        }) {
            Image(systemName: inCalibrationMode ? "circle.fill" : "circle")
                .foregroundColor(inCalibrationMode ? .red : .green)
                .font(.system(size: 40))
        }
        .padding()
    }
}

struct ToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        ToggleButton(inCalibrationMode: .constant(false))
    }
}
