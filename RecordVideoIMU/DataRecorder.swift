//
//  DataRecorder.swift
//  RecordVideoIMU
//
//  Created by Joshua Yang on 2023/5/2.
//

import Foundation
import AVFoundation
import CoreMedia
import CoreMotion
import UIKit
import ARKit
import SceneKit

class DataRecorder: NSObject, ObservableObject, ARSessionDelegate {
    @Published var inCalibrationMode = false
    var captureFrame = false
    
    let motionManager = CMMotionManager()
    
    var documentsDirectory: URL
    var offsetTimestamp: CMTime?
    var offsetRecorded = false
    
    
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var videoWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var isRecording = false
    
    // ARKit related properties
    var arSession: ARSession?
    @Published var cameraImage: UIImage?
    
    var videoFrameNum = 0
    var depthMapNum = 0
    
    
    override init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let dataDirectory = documentsDirectory.appendingPathComponent("Data")
        if !FileManager.default.fileExists(atPath: dataDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
        self.documentsDirectory = dataDirectory
        super.init()
    }
    
    func startRecording() {
        let videoURL = documentsDirectory.appendingPathComponent("videoData.mov")
        resetFiles()
        
        let desiredHeight: CGFloat = 1440
        let desiredWidth = round(desiredHeight * 4 / 3) // Maintain a 4:3 aspect ratio
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: desiredWidth,
            AVVideoHeightKey: desiredHeight
        ]
        
        let videoWriterAdaptorAttributes: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: desiredWidth,
            AVVideoHeightKey: desiredHeight
        ]
        
        // Configure video writer
        videoWriter = try! AVAssetWriter(outputURL: videoURL, fileType: .mov)
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        videoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput!,
                                                                  sourcePixelBufferAttributes: videoWriterAdaptorAttributes)
        videoWriter?.add(videoWriterInput!)
        
        // Start recording
        self.videoWriter?.startWriting()
        self.videoWriter?.startSession(atSourceTime: .zero)
        self.isRecording = true
        
    }
    
    func endRecording() {
        // end recording
        isRecording = false
        videoWriterInput?.markAsFinished()
        
        videoWriter?.finishWriting {
            print("Video Finished!!")
        }
        
        // Release resources
        self.videoWriter = nil
        self.videoWriterInput = nil
        self.videoWriterAdaptor = nil
        
        self.videoFrameNum = 0
        self.depthMapNum = 0
        
        self.offsetRecorded = false
    }
    
    func startSession() {
        // create calibration photo file
        resetFiles()
        let calibrateURL = documentsDirectory.appendingPathComponent("calibration")
        
        if FileManager.default.fileExists(atPath: calibrateURL.path) {
            do {
                try FileManager.default.removeItem(at: calibrateURL)
                print("calibration file deleted successfully")
            } catch let error {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        
        do {
            if !FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent("calibration").path) {
                try FileManager.default.createDirectory(at: documentsDirectory.appendingPathComponent("calibration"), withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("Failed to create calibration folder: \(error)")
        }
        
        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = 1 / 60 // 60 Hz
        
        // Create an AR configuration with depth data enabled
        guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else { return }
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.isAutoFocusEnabled = true // Optional: Disable autofocus for continuous focus
        arConfiguration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        
        arSession = ARSession()
        arSession?.delegate = self
        arSession?.run(arConfiguration)
        self.motionManager.startDeviceMotionUpdates()
        
    }
    
    func endSession() {
        motionManager.stopDeviceMotionUpdates()
        // Stop the AR session
        arSession?.pause()
        arSession = nil
    }
    
    func resetFiles() {
        let videoURL = documentsDirectory.appendingPathComponent("videoData.mov")
        let imuURL = documentsDirectory.appendingPathComponent("imuData.csv")
        let depthBufferURL = documentsDirectory.appendingPathComponent("depthBuffer")
        
        if FileManager.default.fileExists(atPath: videoURL.path) {
            do {
                try FileManager.default.removeItem(at: videoURL)
                print("video file deleted successfully")
            } catch let error {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        
        if FileManager.default.fileExists(atPath: imuURL.path) {
            do {
                try FileManager.default.removeItem(at: imuURL)
                print("IMU file deleted successfully")
            } catch let error {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        
        if FileManager.default.fileExists(atPath: depthBufferURL.path) {
            do {
                try FileManager.default.removeItem(at: depthBufferURL)
                print("Depth buffer file deleted successfully")
            } catch let error {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Get the synchronized video sample buffer from the ARFrame
        let videoSampleBuffer = frame.capturedImage
        
        // Get the depth data from the ARFrame
        guard let depthData = frame.sceneDepth?.depthMap else{
            print("retreive depth data failed!")
            return
        }
        
        // Get the camera image from ARFrame
        let image = frame.capturedImage
        if let uiImage = convertPixelBufferToUIImage(pixelBuffer: image) {
           // Publish the camera image
           DispatchQueue.main.async {
               self.cameraImage = uiImage
           }
        }
        
        
        if !inCalibrationMode {
            if isRecording {
                // If start of recording, get the current timestamp to offset the subsequent timestamps
                if !offsetRecorded {
                    self.offsetTimestamp = CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000)
                    offsetRecorded = true
                }
                
                // Get timestamp of video frame
                let timestamp = frame.timestamp

                // Get IMU data for timestamp
                if let motion = motionManager.deviceMotion {
                    print((motion.timestamp - timestamp))
                    let imuData = "\(motion.attitude.roll),\(motion.attitude.pitch),\(motion.attitude.yaw),\(motion.rotationRate.x),\(motion.rotationRate.y),\(motion.rotationRate.z),\(motion.userAcceleration.x),\(motion.userAcceleration.y),\(motion.userAcceleration.z)"
                    
                    // Write video frame and IMU data to file
                    if !FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent("videoData.mov").path) {
                        FileManager.default.createFile(atPath: documentsDirectory.appendingPathComponent("videoData.mov").path, contents: nil, attributes: nil)
                    }
                    //                guard let pixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer) else { return }
                    
                    while !videoWriterAdaptor!.assetWriterInput.isReadyForMoreMediaData {}
                    videoFrameNum += 1
                    let success = videoWriterAdaptor!.append(videoSampleBuffer, withPresentationTime: CMTimeSubtract(CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000), self.offsetTimestamp!))
                    if !success {
                        print("Failed to write video frame")
                    }
                    
                    if !FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent("imuData.csv").path) {
                        FileManager.default.createFile(atPath: documentsDirectory.appendingPathComponent("imuData.csv").path, contents: nil, attributes: nil)
                    }
                    
                    let imuDataPath = documentsDirectory.appendingPathComponent("imuData.csv")
                    let imuDataString = "\(motion.timestamp - self.offsetTimestamp!.seconds),\(imuData)\n"
                    if let fileHandle = FileHandle(forWritingAtPath: imuDataPath.path) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(imuDataString.data(using: .utf8)!)
                        fileHandle.closeFile()
                    } else {
                        do {
                            try imuDataString.write(toFile: imuDataPath.path, atomically: true, encoding: .utf8)
                        } catch {
                            print("Failed to write IMU data to disk")
                        }
                    }
                    
                    
                    // Write depth buffer
                    do {
                        if !FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent("depthBuffer").path) {
                            try FileManager.default.createDirectory(at: documentsDirectory.appendingPathComponent("depthBuffer"), withIntermediateDirectories: true, attributes: nil)
                        }
                    } catch {
                        print("Failed to create folder: \(error)")
                    }
                    
                    CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
                    let addr = CVPixelBufferGetBaseAddress(depthData)
                    let height = CVPixelBufferGetHeight(depthData)
                    let bpr = CVPixelBufferGetBytesPerRow(depthData)
                    let data = Data(bytes: addr!, count: (bpr * height))
                    do {
                        let bufferName = "\(CMTimeSubtract(CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000), self.offsetTimestamp!).seconds)_depthBuffer.bin"
                        let bufferURL = documentsDirectory.appendingPathComponent("depthBuffer")
                        let bufferFileURL = bufferURL.appendingPathComponent(bufferName)
                        try data.write(to: bufferFileURL)
                    } catch {
                        print("Error while writing buffer")
                    }
                    CVPixelBufferUnlockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
                    
                    
                }
                
                print(videoFrameNum)

            }
        }
        else if captureFrame {
            // capture the current frame for calibration purpose
            guard let imageData = self.cameraImage!.rotateCounterclockwise()!.pngData() else {
                print("Failed to convert image to PNG data")
                return
            }

            do {
                let calibrationName = "\(CMTimeMakeWithSeconds(frame.timestamp, preferredTimescale: 1000).seconds)_calibration.png"
                let calibrationURL = documentsDirectory.appendingPathComponent("calibration")
                let calibrationFileURL = calibrationURL.appendingPathComponent(calibrationName)
                try imageData.write(to: calibrationFileURL)
                print("Image saved successfully")
            } catch {
                print("Error saving image: \(error.localizedDescription)")
            }
            
            self.captureFrame = false
        }
    }
    
    func convertPixelBufferToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply a rotation transform of 90 degrees clockwise
        let rotationTransform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        let rotatedCIImage = ciImage.transformed(by: rotationTransform)
        
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(rotatedCIImage, from: rotatedCIImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage
        }
        
        return nil
    }
    
}


extension UIImage {
    func rotateCounterclockwise() -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        let rotatedSize = CGSize(width: self.size.height, height: self.size.width)
        let bounds = CGRect(x: 0, y: 0, width: rotatedSize.width, height: rotatedSize.height)
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        context.rotate(by: -CGFloat.pi / 2)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}
