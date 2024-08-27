//
//  PictureButton.swift
//  RecordVideoIMU
//
//  Created by Joshua Yang on 2023/6/13.
//

import SwiftUI
import AVFoundation

struct PictureButton: View {
    @Binding var takingPicture: Bool
    
    private let shutterSoundPlayer: AVAudioPlayer? = {
        guard let soundURL = Bundle.main.url(forResource: "shutter_sound", withExtension: "mp3") else {
            return nil
        }
        
        do {
            return try AVAudioPlayer(contentsOf: soundURL)
        } catch {
            return nil
        }
    }()
        

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 6)
                .foregroundColor(.white)
                .frame(width: 65, height: 65)

            RoundedRectangle(cornerRadius: 55 / 2)
                .foregroundColor(.white)
                .frame(width: 55, height: 55)
        }
        .padding(20)
        .onTapGesture {
            takingPicture = true
            AudioServicesPlaySystemSound(1108)
        }
    }

    
}

struct PictureButton_Previews: PreviewProvider {
    static var previews: some View {
        PictureButton(takingPicture: .constant(false))
    }
}
