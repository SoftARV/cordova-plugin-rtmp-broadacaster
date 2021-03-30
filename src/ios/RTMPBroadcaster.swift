//
//  RTMPBroadcaster.swift
//  
//
//  Created by Miguel on 3/24/21.
//

import Foundation
import AVFoundation
import HaishinKit

@objc(RTMPBroadcaster) public class RTMPBroadcaster: CDVPlugin {
    private var originalBackgroundColor: UIColor!
    
    var cameraView: MTHKView!
    private var rtmpConnection: RTMPConnection!
    private var rtmpStream: RTMPStream!
    private var currentPosition: AVCaptureDevice.Position!
    
    override public init() {
        super.init()

        originalBackgroundColor = self.webView.backgroundColor;
        configureAudioSession()
    }
    
    // MARK: stream options
    
    @objc(showCameraFeed:)
    func showCameraFeed(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "The Plugin Failed")
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        
        // TODO: change camera settings from the Js side
        if let orientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
            rtmpStream.orientation = orientation
        }
        
        rtmpStream.captureSettings = [
            .fps: 30,
            .sessionPreset: AVCaptureSession.Preset.high
        ]
        rtmpStream.videoSettings = [
            .width: 720,
            .height: 1280,
            .bitrate: 512 * 1000,
        ]
        
        rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio)) { error in
            print(error)
            return
        }
        currentPosition = .back
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: currentPosition)) { error in
            print(error)
            return
        }
        
        cameraView = MTHKView(frame: self.webView.frame)
        cameraView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraView.attachStream(rtmpStream)
        
        self.webView.isOpaque = false
        self.webView.backgroundColor = UIColor.clear
        self.webView.superview?.insertSubview(cameraView, belowSubview: self.webView)
        
        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Showing camera")
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    @objc(removeCameraFeed:)
    func removeCameraFeed(command: CDVInvokedUrlCommand) {
        self.webView.isOpaque = true
        self.webView.backgroundColor = originalBackgroundColor
        cameraView.removeFromSuperview()
    }
    
    @objc(rotateCamera:)
    func rotateCamera(command: CDVInvokedUrlCommand) {
        let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        rtmpStream.captureSettings[.isVideoMirrored] = position == .front
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) {error in
            print(error)
        }
        currentPosition = position
    }
    
    @objc(startStream:)
    func startStream(command: CDVInvokedUrlCommand) {
        let url = command.arguments[0] as? String ?? ""
        let id = command.arguments[1] as? String ?? ""

        rtmpConnection.connect(url)
        rtmpStream.publish(id)
    }
    
    @objc(stopStream:)
    func stopStream(command: CDVInvokedUrlCommand) {
        rtmpConnection.close()
    }
    
    
    // MARK: audio sesion configuration
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Cannot initialize the camera, please restart the app and try again")
            return
        }
    }
    
}
