//
//  ViewController.swift
//  Swift4.2
//
//  Created by macOS on 22.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//

import UIKit
import WebRTC

private let kARDMediaStreamId = "ARDAMS"
private let kARDAudioTrackId = "ARDAMSa0"
private let kARDVideoTrackId = "ARDAMSv0"


//, WebSocketDelegate
class ViewController: UIViewController, RTCPeerConnectionDelegate, RTCEAGLVideoViewDelegate, WebSocketDelegate {

    
    
    
    
    @IBOutlet weak var joinButtonO: UIButton!
    var factory: RTCPeerConnectionFactory?
    private var localView: RTCCameraPreviewView?
    
    var delegate: WebSocketDelegate?
    var websocket: WebSocketChannel?
    var peerConnectionDict: [Int: AnyObject]?
    var publisherPeerConnection: RTCPeerConnection?
    var localTrack: RTCVideoTrack?
    var localAudioTrack: RTCAudioTrack?
    var height: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        joinButtonO.addTarget(self, action: #selector(ViewController.joinClicked(_:)), for: .touchUpInside)
        
    }
    //change, added joinButtonO and writed joinButtonO code
    @objc func joinClicked(_ button: UIButton?) {
        joinButtonO.isHidden = true
        //* change, moved in joinButtonO method
        localView = RTCCameraPreviewView(frame: CGRect(x: 0, y: 0, width: 480, height: 360))
        view.addSubview(localView!)
        
        let url = URL(string: "ws://212.175.20.72:8188/janus") //changed: added hostname and port (with janus)
        if let anUrl = url {
            websocket = WebSocketChannel(url: anUrl)
            websocket?.delegate = self
        }
        //        delegate!.delegate = WebSocketDelegate
        
        peerConnectionDict = [:]
        factory = RTCPeerConnectionFactory()
        localTrack = createLocalVideoTrack()
        localAudioTrack = createLocalAudioTrack()
        //*
    }
    func updateViews() -> Void {
    }
    func createRemoteView() -> RTCEAGLVideoView {
        height += 180
        let remoteView = RTCEAGLVideoView(frame: CGRect(x: 0, y: height, width: 240, height: 180))
        remoteView.delegate = self
        view.addSubview(remoteView)
        return remoteView
    }
    func createPublisherPeerConnection() {
        publisherPeerConnection = createPeerConnection()
        createAudioSender(publisherPeerConnection!)
        createVideoSender(publisherPeerConnection!)
    }
    func defaultPeerConnectionConstraints() -> RTCMediaConstraints? {
        let mandatoryConstraints = [
            "OfferToReceiveAudio" : "true",
            "OfferToReceiveVideo" : "true",
            ]
        let optionalConstraints = [
            "DtlsSrtpKeyAgreement" : "true"
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: optionalConstraints) //changed: "nil" to mandatoryConstraints
        return constraints
    }
    func defaultSTUNServer() -> [RTCIceServer]? {
//        let turn =  RTCIceServer(urlStrings: [ "turn:13.250.13.83:3478?transport=udp",
//                                               "turn:13.250.13.83:3478?transport=tcp"], username: "YzYNCouZM1mhqhmseWk6", credential: "YzYNCouZM1mhqhmseWk6")
//        let stun = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"], username: "", credential: "")
//        return [stun, turn]
        let stun = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"], username: "", credential: "")
        let turn = RTCIceServer(urlStrings: ["turn:stun.liveswitch.fm:3478"], username: "test", credential: "pa55w0rd!")
        return [stun, turn]
    }
    func createPeerConnection() -> RTCPeerConnection? {
        let constraints: RTCMediaConstraints? = defaultPeerConnectionConstraints()
        let config: RTCConfiguration? = RTCConfiguration()
        let iceServers = defaultSTUNServer()
        config!.iceServers = iceServers!
        config!.iceTransportPolicy = .relay // enum error
        let peerConnection: RTCPeerConnection = (factory?.peerConnection(with: config!, constraints: constraints!, delegate: self))!
        return peerConnection
    }
    func offerPeerConnection(_ handleId: Int) {
        self.createPublisherPeerConnection()
        let jc: JanusConnection = JanusConnection(with: handleId)
        jc.connection = publisherPeerConnection
        peerConnectionDict![handleId] = jc
        publisherPeerConnection!.offer(for: defaultOfferConstraints()!, completionHandler: { sdp, error in
            self.publisherPeerConnection!.setLocalDescription(sdp!, completionHandler: { error in
                self.websocket!.publisherCreateOffer(handleId, sdp: sdp)
            })
        })
        
    }
    func defaultMediaAudioConstraints() -> RTCMediaConstraints? {
        let mandatoryConstraints = [kRTCMediaConstraintsLevelControl: kRTCMediaConstraintsValueFalse]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
        return constraints
    }
    func defaultOfferConstraints() -> RTCMediaConstraints? {
        let mandatoryConstraints = ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"]
        let optionalConstraints = ["DtlsSrtpKeyAgreement": "true"] //changed: added optionalConstaints (ff-t)/(tt-f)
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: optionalConstraints) //changed: "nil" to "optionalconstraints"
        return constraints
    }
    func createLocalAudioTrack() -> RTCAudioTrack? {
        let constraints: RTCMediaConstraints? = defaultMediaAudioConstraints()
        let source: RTCAudioSource? = factory!.audioSource(with: constraints)
        let track: RTCAudioTrack? = factory!.audioTrack(with: source!, trackId: kARDAudioTrackId)
        
        return track
    }
    func createAudioSender(_ peerConnection: RTCPeerConnection) -> RTCRtpSender? {
        let sender: RTCRtpSender? = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: kARDMediaStreamId)
        if (localAudioTrack != nil) {
            sender?.track = localAudioTrack
        }
        return sender
    }
    func createLocalVideoTrack() -> RTCVideoTrack? {
        let cameraConstraints = RTCMediaConstraints(mandatoryConstraints: (currentMediaConstraint() as! [String : String]), optionalConstraints: nil)
        let source: RTCAVFoundationVideoSource? = factory!.avFoundationVideoSource(with: cameraConstraints)
        let localVideoTrack: RTCVideoTrack? = factory!.videoTrack(with: source!, trackId: kARDVideoTrackId)
        localView!.captureSession = source?.captureSession
        
        return localVideoTrack
    }
    func createVideoSender(_ peerConnection: RTCPeerConnection) -> RTCRtpSender? {
        let sender: RTCRtpSender? = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo, streamId: kARDMediaStreamId)
        if (localTrack != nil) {
            sender?.track = localTrack
        }
        
        return sender
    }
    func currentMediaConstraint() -> [String: AnyObject]? {
        var mediaConstraintsDictionary: [String : AnyObject]? = nil
        
        let widthConstraint = "480"
        let heightConstraint = "360"
        let frameRateConstrait = "20"
        if widthConstraint != "" && heightConstraint != "" {
            mediaConstraintsDictionary = [kRTCMediaConstraintsMinWidth: widthConstraint, kRTCMediaConstraintsMaxWidth: widthConstraint, kRTCMediaConstraintsMinHeight: heightConstraint, kRTCMediaConstraintsMaxHeight: heightConstraint, kRTCMediaConstraintsMaxFrameRate: frameRateConstrait] as [String : AnyObject]
        }
        return mediaConstraintsDictionary
    }
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        var rect: CGRect? = videoView.frame
        rect?.size = size
        print(String(format: "========didChangeVideiSize %fx%f", size.width, size.height))
        videoView.frame = rect!
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("=========didAddStream")
        var janusConnection: JanusConnection?
        for item in peerConnectionDict! {
            if let jc: JanusConnection = peerConnectionDict![item.key] as? JanusConnection {
                if peerConnection == jc.connection {
                    janusConnection = jc
                    break
                }
            }
            //            if let aKey = key {
            //                jc = peerConnectionDict[aKey]
            //            }
        }
        DispatchQueue.main.async(execute: {
            //move to main thread
            if stream.videoTracks.count > 0 {
                let remoteVideoTrack: RTCVideoTrack? = stream.videoTracks[0]
                
                let remoteView: RTCEAGLVideoView? = self.createRemoteView()
                if let aView = remoteView {
                    remoteVideoTrack?.add(aView)
                }
                janusConnection?.videoTrack = remoteVideoTrack
                janusConnection?.videoView = remoteView
            }
        })
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("=========didRemoveStream")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        //change: added NSLOG/switch
        //NSLog(@"⭕️didChangeSignalingState %ld", (long)stateChanged);
        switch stateChanged {
        case .stable:
            print("⭕️didChangeSignalingState RTCSignalingStateStable")
        case .haveLocalOffer:
            print("⭕️didChangeSignalingState RTCSignalingStateHaveLocalOffer")
        case .haveLocalPrAnswer:
            print("⭕️didChangeSignalingState RTCSignalingStateHaveLocalPrAnswer")
        case .haveRemoteOffer:
            print("⭕️didChangeSignalingState RTCSignalingStateHaveRemoteOffer")
        case .haveRemotePrAnswer:
            print("⭕️didChangeSignalingState RTCSignalingStateHaveRemotePrAnswer")
        case .closed:
            print("⭕️didChangeSignalingState RTCSignalingStateClosed")
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("=========didGenerateIceCandidate==\(candidate.sdp)")
        
        var handleId: Int?
        for item in peerConnectionDict! {
            let jc: JanusConnection = peerConnectionDict![item.key] as! JanusConnection
            //            if let aKey = key {
            //                jc = peerConnectionDict[aKey]
            //            }
            if peerConnection == jc.connection {
                handleId = Int(integerLiteral: jc.handleId ?? 0) //jc.handleId as! NSNumber
                break
            }
        }
        if candidate != nil {
            websocket!.trickleCandidate(handleId, candidate: candidate)
        } else {
            websocket!.trickleCandidateComplete(handleId)
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        //        change: added NSLOG/switch
        //        NSLog(@"⭕️didChangeIceGatheringState %ld", (long)newState);
        switch newState {
        case .new:
            print("⭕️didChangeIceGatheringState RTCIceGatheringStateNew")
        case .gathering:
            print("⭕️didChangeIceGatheringState RTCIceGatheringStateGathering")
        case .complete:
            print("⭕️didChangeIceGatheringState RTCIceGatheringStateComplete")
        default:
            break
        }
    }
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        //change: added NSLOG/switch
        //NSLog(@"⭕️didChangeIceConnectionState %ld", (long)newState);
        switch newState {
        case .new:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateNew")
        case .checking:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateChecking")
        case .connected:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateConnected")
        case .completed:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateCompleted")
        case .failed:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateFailed")
        case .disconnected:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateDisconnected")
        case .closed:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateClosed")
        case .count:
            print("⭕️didChangeIceConnectionState RTCIceConnectionStateCount")
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("=========didRemoveIceCandidates")
    }
    
    // mark: delegate
    func onPublisherJoined(handleId: Int?) {
        self.offerPeerConnection(handleId ?? 0)
//        offerPeerConnection(handleId!)
    }
//    func onPublisherRemoteJsep(handleId: Int?, dict jsep: [String : AnyObject]) {
//        <#code#>
//    }
    func onPublisherRemoteJsep(handleId: Int?, dict jsep: [String : AnyObject]) {
        //TODO: Bug
        let jc: JanusConnection? = (peerConnectionDict![handleId!] as! JanusConnection)
        //        if let anId = handleId as [String: Any]{
        //            jc = peerConnectionDict![anId]
        //        }
        let answerDescription = RTCSessionDescription(fromJSONDictionary: jsep as [String : AnyObject])
        jc?.connection!.setRemoteDescription(answerDescription, completionHandler: { error in
        })
    }

    func subscriberHandleRemoteJsep(handleId: Int?, dict jsep: [String : AnyObject]) {
        let peerConnection: RTCPeerConnection? = createPeerConnection()
        
        let jc = JanusConnection(with: handleId!)
        jc.connection = peerConnection
        jc.handleId = (handleId)
        if let anId = handleId {
            peerConnectionDict![anId] = jc
        }
        
        let answerDescription = RTCSessionDescription(fromJSONDictionary: jsep)
        peerConnection?.setRemoteDescription(answerDescription, completionHandler: { error in
        })
        let mandatoryConstraints = ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"]
        let optionalConstraints = ["DtlsSrtpKeyAgreement": "true"] //changed: added optionalconstraints (ff-t)/(tt-f)
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: optionalConstraints) //changed: "nil" to "optionalconstraints"
        
        peerConnection?.answer(for: constraints, completionHandler: { sdp, error in
            peerConnection?.setLocalDescription(sdp!, completionHandler: { error in
            })
            self.websocket!.subscriberCreateAnswer(handleId, sdp: sdp) // change, commanded
        })
    }
    //TODO: required init
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }
    func onLeaving(handleId: Int?) {
        let jc: JanusConnection! = (peerConnectionDict![handleId!] as! JanusConnection)
        //        var jc: JanusConnection? = nil
        //        if let anId = handleId {
        //            jc = peerConnectionDict![anId]
        //        }
        jc?.connection!.close()
        jc?.connection = nil
        var videoTrack: RTCVideoTrack? = jc?.videoTrack
        videoTrack?.remove((jc?.videoView)!)
        videoTrack = nil
        jc?.videoView!.renderFrame(nil)
        jc?.videoView!.removeFromSuperview()
        peerConnectionDict?.removeValue(forKey: handleId!)
    }
}


