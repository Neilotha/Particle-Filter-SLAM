//
//  RecordButton.swift
//  RecordVideoIMU
//
//  Created by Joshua Yang on 2023/6/7.
//

import SwiftUI

struct RecordButton: View {
    @State var recording = false
    let startRecordingAction: () -> Void
    let stopRecordingAction: () -> Void
    var action: ((_ recording: Bool) -> Void)?

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 6)
                .foregroundColor(.white)
                .frame(width: 65, height: 65)

            RoundedRectangle(cornerRadius: recording ? 8 : self.innerCircleWidth / 2)
                .foregroundColor(.white)
                .frame(width: self.innerCircleWidth, height: self.innerCircleWidth)
        }
        .animation(.linear(duration: 0.2), value: recording)
        .padding(20)
        .onTapGesture {
            withAnimation {
                self.recording.toggle()
                if self.recording {
                    startRecordingAction()
                } else {
                    stopRecordingAction()
                }
                self.action?(self.recording)
            }
        }
    }

    var innerCircleWidth: CGFloat {
        self.recording ? 32 : 55
    }
}
