//
//  RTMPBroadcaster.swift
//  
//
//  Created by Miguel on 3/24/21.
//

import AVFoundation
import HaishinKit

@objc(RTMPBroadcaster) 
public class RTMPBroadcaster: CDVPlugin {
    private var originalBackgroundColor: UIColor!
    private var cameraView: MTHKView!
    private var rtmpConnection: RTMPConnection!
    private var rtmpStream: RTMPStream!
    private var currentPosition: AVCaptureDevice.Position!
    
    // Broadcast info
    private var url: String = ""
    private var id: String = ""
    
    // broadcast helpers
    private var retryCount: Int = 0
    private var maxRetryCount: Int = 5
    
    
    override public init() {
        super.init()

        originalBackgroundColor = self.webView.backgroundColor;
        configureAudioSession()
    }
    
    // MARK: stream options
    
    @objc(showCameraFeed:)
    func showCameraFeed(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "The Plugin Failed")
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.commandDelegate!.run {
            self.rtmpConnection = RTMPConnection()
            self.rtmpStream = RTMPStream(connection: self.rtmpConnection)
            
            // TODO: change camera settings from the Js side
            if let orientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
                self.rtmpStream.orientation = orientation
            }
            
            self.rtmpStream.captureSettings = [
                .fps: 30,
                .sessionPreset: AVCaptureSession.Preset.high
            ]
            self.rtmpStream.audioSettings = [
                .muted: false,
                .bitrate: 64 * 1000
            ]
            self.rtmpStream.videoSettings = [
                .width: 720,
                .height: 1280,
                .bitrate: 512 * 1000,
            ]
            self.rtmpStream.attachAudio(AVCaptureDevice.default(for: AVMediaType.audio)) { error in
                print(error)
                return
            }
            self.currentPosition = .back
            self.rtmpStream.attachCamera(DeviceUtil.device(withPosition: self.currentPosition)) { error in
                print(error)
                return
            }
            
        }
        
        self.cameraView = MTHKView(frame: self.webView.bounds)
        self.cameraView.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.cameraView.attachStream(self.rtmpStream)
        
        self.webView.isOpaque = false
        self.webView.backgroundColor = UIColor.clear
        self.webView.superview?.insertSubview(cameraView, belowSubview: self.webView)
        
        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Showing camera")
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    @objc(removeCameraFeed:)
    func removeCameraFeed(command: CDVInvokedUrlCommand) {
        UIApplication.shared.isIdleTimerDisabled = false
        self.webView.isOpaque = true
        self.webView.backgroundColor = originalBackgroundColor
        cameraView.removeFromSuperview()
    }
    
    @objc(rotateCamera:)
    func rotateCamera(command: CDVInvokedUrlCommand) {
        let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) {error in
            print(error)
        }
        currentPosition = position
    }
    
    @objc(startStream:)
    func startStream(command: CDVInvokedUrlCommand) {
        url = command.arguments[0] as? String ?? ""
        id = command.arguments[1] as? String ?? ""
        
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(broadcastStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(broadcastErrorHandler), observer: self)
        rtmpConnection.connect(url)
    }
    
    @objc(stopStream:)
    func stopStream(command: CDVInvokedUrlCommand) {
        rtmpConnection.close()
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(broadcastStatusHandler), observer: self)
        rtmpConnection.removeEventListener(.ioError, selector: #selector(broadcastErrorHandler), observer: self)
    }
    
    // MARK: Stream observers
    
    @objc
    private func broadcastStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        print("broadcast status:", code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.publish(id)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(url)
            retryCount += 1
        default:
            break
        }
    }
    
    @objc
    private func broadcastErrorHandler(_ notification: Notification) {
        print("broadcast error:",notification)
        rtmpConnection.connect(url)
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
