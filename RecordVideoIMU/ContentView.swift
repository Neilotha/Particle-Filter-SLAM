//
//  ContentView.swift
//  RecordVideoIMU
//
//  Created by Joshua Yang on 2023/5/2.
//

import SwiftUI

struct ContentView: View {
    @StateObject var recorder = DataRecorder()
    @State private var cameraImage: UIImage?
    var body: some View {
        VStack {
            Spacer()
            
            VStack {
                Image(uiImage: cameraImage ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 800, height: 600)
            }
            .onReceive(recorder.$cameraImage) { image in
                cameraImage = image
            
            }

            Spacer()
            
            HStack {
                Spacer()
                Spacer()
                
                if !recorder.inCalibrationMode {
                    RecordButton( startRecordingAction: recorder.startRecording, stopRecordingAction: recorder.endRecording)
                }
                else {
                    PictureButton(takingPicture: $recorder.captureFrame)
                }
                Spacer()
                ToggleButton(inCalibrationMode: $recorder.inCalibrationMode)
            }
            .padding()
            
        }
        .onAppear {
            recorder.startSession()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
