//
//  WebSocketChannelSwift.swift
//  Swift4
//
//  Created by macOS on 23.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//

import Foundation
import WebRTC
import SocketRocket


private let kJanus = "janus"
private let kJanusData = "data"
//private var room: UInt64 = 1234
//
class WebSocketChannel: NSObject, SRWebSocketDelegate {
    
//    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {}
    
    private var state: ARDSignalingChannelState = .kARDSignalingChannelStateClosed
    private var url: URL?
    private var socket: SRWebSocket?
    private var sessionId: Int?
    private var keepAliveTimer: Timer!
    private var transDict: [String: AnyObject]//NSMutableDictionary değiştirilebilir yaratılan nesne
    private var handleDict:  [AnyHashable : AnyObject]
    private var feedDict:  [AnyHashable : AnyObject]

    var delegate: WebSocketDelegate?
  
    init(url: URL) {
        transDict = [:]
        handleDict = [:]
        feedDict = [:]
        
        super.init()
        
        self.url = url
        let protocols = ["janus-protocol"]
        socket = SRWebSocket(url: url, protocols: protocols)
        socket?.delegate = self

//        keepAliveTimer.invalidate()
        print("Opening WebSocket.")
        socket?.open()
        
    }
    deinit {
        disconnect()
    }
    func setState(state: ARDSignalingChannelState) {
        if self.state == state {
            return
        }
        self.state = state
    }
    func disconnect() {
        if state == .kARDSignalingChannelStateClosed || state == .kARDSignalingChannelStateError {
            return
        }
        socket?.close()
        print("C->WSS DELETE close")
    }
    // MARK: - SRWebSocketDelegate
    func webSocketDidOpen(_ webSocket: SRWebSocket?) {
        print("WebSocket connection opened.")
        state = .kARDSignalingChannelStateOpen
        createSession()
    }

    func webSocket(_ webSocket: SRWebSocket?, didReceiveMessage message: Any?) {
        if let aMessage = message {
            print("====onIncomingMessage=\(aMessage)")
        }
//        let messageData: Data? = (message as AnyObject).data(using: String.Encoding.utf8.rawValue)
//        let jsonObject = try? JSONSerialization.jsonObject(with: messageData!, options:[]) as! [String: AnyObject]
//        if (jsonObject == nil) {
//            print("Unexpected message: \(String(describing: jsonObject))")
//            return
//        }
        let messageData: Data? = (message as AnyObject).data(using: String.Encoding.utf8.rawValue)
        var jsonObject: Any? = nil
        if let aData = messageData {
            jsonObject = try? JSONSerialization.jsonObject(with: aData, options: []) as Any
        }
        if !(jsonObject is [AnyHashable : Any]) {
            if let anObject = jsonObject {
                print("Unexpected message: \(anObject)")
            }
            return
        }
//        if !(jsonObject != nil) {
//            if let anObject = jsonObject {
//                print("Unexpected message: \(anObject)")
//            }
//            return
//        }
        let wssMessage = jsonObject as? [AnyHashable : Any]
        let janus = wssMessage![kJanus] as! String
        if (janus == "success"){
            let transaction = wssMessage!["transaction"] as! String
            let jt: JanusTransaction = transDict[transaction] as! JanusTransaction
            if (jt.success != nil){
                jt.success!(wssMessage as? [String : AnyObject])
            }
            transDict.removeValue(forKey: transaction)
        }
        else if(janus == "error"){
//            let transaction = wssMessage["transaction"] as! String
//            let jt:JanusTransaction = transDict[transaction] as! JanusTransaction
//            if (jt.error != nil){
//                jt.error!(wssMessage as [String : AnyObject])
//            }
            let transaction = wssMessage!["transaction"] as! String
            let jt: JanusTransaction? = transDict[transaction]  as? JanusTransaction
            if jt?.error != nil {
                jt?.error?(wssMessage as? [String : AnyObject])
            }
            transDict.removeValue(forKey: transaction)
        }
        else if(janus == "ack"){
            print("Just an ack")
        }
        else{
           // wssMessage = wssMessage["sender"] as JanusHa
            let handle: JanusHandle? = (handleDict[wssMessage!["sender"] as! AnyHashable] as! JanusHandle)
            if(handle == nil){
                print("missing handle?")
            }
            else if(janus == "event"){
                if let pluginData = wssMessage!["plugindata"] as? [String: AnyObject] {
                    if let plugin = pluginData["data"] as? [String:AnyObject]  {
                        if let videoRoom = plugin["videoroom"] as? String, videoRoom == "joined" {
                            handle?.onJoined!(handle)
                        }
//                        let arrays = plugin["publishers"] as! [AnyObject]
//                        if arrays != nil && arrays.count > 0 {
//                            for publisher in arrays {
//                                let feed = publisher["id"]
//                                let display = publisher["display"] as? String
//                                subscriberCreateHandle(feed: feed as! Int, display: display!)
//                            }
//                        }
                        if let publisher = plugin["publishers"] as? [AnyObject], publisher.count > 0 {
                            for item in publisher {
                                if let feed = item["id"] as? Int, let display = item["display"] as? String{
                                    subscriberCreateHandle(feed: feed, display: display)
                                }
                            }
                        }
                        if let leaving = plugin["leaving"] as? String {
                            if let jhandle: JanusHandle = feedDict[leaving] as? JanusHandle {
                                jhandle.onLeaving!(jhandle)
                            }
                        }
                    }
                }
                if let jsep = wssMessage!["jsep"] as? [String : AnyObject] {
                    handle!.onRemoteJsep!(handle, jsep as [String : AnyObject])
                }
            }
            else if(janus == "detached"){
                handle!.onLeaving!(handle)
            }
        }
    }
//    func webSocket(webSocket: SRWebSocket?) throws {
//        RTCLogError("WebSocket error: %@", error)
//        state = .kARDSignalingChannelStateError
//    }
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("WebSocket error: ", error)
        state = .kARDSignalingChannelStateError
    }
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("WebSocket closed with code: \(code) reason:\(reason ?? "no reason") wasClean:\(wasClean)")
        assert(state !=  .kARDSignalingChannelStateError, "Invalid parameter not satisfying: state != kARDSignalingChannelStateError")
        state = .kARDSignalingChannelStateClosed //kARDSignalingChannelStateClosed
        keepAliveTimer.invalidate()
    }
    
    // MARK: - Private
//    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    func randomStringWithLength(len: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0...len-1).map{ _ in letters.randomElement()! })
    }
//    func randomStringWithLength(len: Int) -> String {
//        var randomString = String(repeating: "\0", count: len)
//        for _ in 0..<len {
//            let data = arc4random_uniform(UInt32(letters.count)) // length() is fail
//           //randomString +=  "\(letters.index(letters.startIndex, offsetBy: data))q"
//            randomString += "\(letters[letters.index(letters.startIndex, offsetBy: UInt(data))])q"
//        }
//        return randomString
//    }
    func createSession() {
        let transaction = randomStringWithLength(len: 12)
        let jt = JanusTransaction()
        jt.tid = transaction
        jt.success = { data in
            //let x = data?["data"]
            self.sessionId = data?["data"]?["id"] as? Int
            //self.sessionId = (data?["data", default: "id"] as! Int);//warning
            self.keepAliveTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(WebSocketChannel.keepAlive), userInfo: nil, repeats: true)
//            self.keepAliveTimer.fire()
            self.publisherCreateHandle()
        }
        jt.error = {
            data in
        }
        transDict[transaction] = jt
        let createMessage = ["janus": "create", "transaction": transaction]
        socket?.send(jsonMessage(createMessage as [String : AnyObject]))
    }
    func publisherCreateHandle() {
        let transaction = randomStringWithLength(len: 12)
        let jt = JanusTransaction()
        jt.tid = transaction
        jt.success = { data in
            let handle = JanusHandle()
            handle.handleId = data?["data"]!["id"] as? Int
            handle.onJoined = { handle in
                self.delegate?.onPublisherJoined(handleId: handle!.handleId)
//                self.publisherJoinRoom(handle: handle!)
            }
            handle.onRemoteJsep = { handle, jsep in
                self.delegate?.onPublisherRemoteJsep(handleId: handle!.handleId, dict: jsep!)
            }
            if let anId = handle.handleId {
                self.handleDict[anId] = handle
            }
            self.publisherJoinRoom(handle: handle)
        }
        jt.error = {
            data in
        }
        transDict[transaction] = jt
        let attachMessage = [
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "transaction": transaction,
            "session_id": sessionId ?? 0,
            ] as [String : AnyObject]
        socket?.send(jsonMessage(attachMessage))
    }
    func createHandle(_ transValue: String, dict publisher: [String : AnyObject]) {
    }
    func publisherJoinRoom(handle: JanusHandle) {
        let transaction = randomStringWithLength(len: 12)
        let body = [
            "request": "join",
            "room": 1234, //[NSNumber numberWithInteger:room],
            "ptype": "publisher",
            "display": "ios webrtc",
        ] as [String : AnyObject]
        let joinMessage = [
            "janus": "message",
            "transaction": transaction,
            "session_id":sessionId ?? 0,
            "handle_id":handle.handleId ?? 0,
            "body": body,
        ] as [String : AnyObject]
        socket?.send(jsonMessage(joinMessage))
    }
    func publisherCreateOffer(_ handleId: Int?, sdp: RTCSessionDescription?) {
        let transaction = randomStringWithLength(len: 12)
//        let publish = [
//            "request": "configure",
//            "audio": true,
//            "video": true,
//            ] as [String : AnyObject]//change, @YESs to @trues
        //change: audio and video values @true to @YES
        let publish = ["request": "configure", "audio": true, "video": true] as [String : AnyObject] //change, @YESs to @trues
//        let type = RTCSessionDescription.string(for: (sdp?.type)!)
        var type: String? = nil
        if let aType = sdp?.type {
            type = RTCSessionDescription.string(for: aType)
        }
//        let jsep = [
//            "type": type,
//            "sdp": [sdp: sdp],
//            ] as [String : AnyObject]
        var jsep: [String: AnyObject]? = nil
        if let aSdp = sdp?.sdp {
            jsep = ["type": type, "sdp": aSdp] as [String : AnyObject]
        }
//        let offerMessage = [
//            "janus": "message",
//            "body": publish,
//            "jsep": jsep,
//            "transaction": transaction,
//            "session_id": sessionId ?? 0,
//            "handle_id": handleId ?? 0,
//            ] as [String : AnyObject]
        var offerMessage: [String: AnyObject]? = nil
        if let aJsep = jsep, let anId = handleId {
            offerMessage = [
                "janus": "message",
                "body": publish,
                "jsep": aJsep,
                "transaction": transaction,
                "session_id": sessionId ?? 0,
                "handle_id": anId
                ] as [String : AnyObject]
        }
        socket?.send(jsonMessage(offerMessage))
//        socket?.send(jsonMessage(dict: offerMessage as [String : AnyObject]))
    }
    
    func trickleCandidate(_ handleId: Int?, candidate: RTCIceCandidate?) {
        let candidateDict = [
            "candidate": candidate!.sdp as AnyObject,
            "sdpMid": candidate!.sdpMid as AnyObject,
            "sdpMLineIndex": candidate!.sdpMLineIndex,
            ] as [String : AnyObject]
//        var candidateDict: [String : AnyObject?]? = nil
//        if let aSdp = candidate?.sdp, let aMid = candidate?.sdpMid {
//            candidateDict = [
//                "candidate": aSdp,
//                "sdpMid": aMid,
//                "sdpMLineIndex": candidate?.sdpMLineIndex ?? 0] as [String : AnyObject?]
//        }
        let trickleMessage = [
            "janus": "trickle",
            "candidate": candidateDict,
            "transaction": randomStringWithLength(len: 12),
            "session_id":sessionId ?? 0,
            "handle_id":handleId ?? 0,
            ] as [String : AnyObject]
//        var trickleMessage: [String : AnyObject]? = nil
//        if let aDict = candidateDict, let anId = handleId {
//            trickleMessage = [
//                "janus": "trickle",
//                "candidate": aDict,
//                "transaction": randomStringWithLength(len: 12),
//                "session_id": sessionId ?? 0,
//                "handle_id": anId] as [String : AnyObject]
//        }
        print("===trickle==\(trickleMessage)")
//        if let aMessage = trickleMessage {
//            print("===trickle==\(aMessage)")
//        }
        socket?.send(jsonMessage(trickleMessage))
        
    }
    
    func trickleCandidateComplete(_ handleId: Int?) {
        let candidateDict = [
            "completed": true,
        ] as [String: AnyObject]
        let trickleMessage = [
            "janus": "trickle",
            "candidate": candidateDict,
            "transaction": [randomStringWithLength(len: 12)],
            "session_id":sessionId ?? 0,
            "handle_id":handleId ?? 0,
        ] as [String: AnyObject]
        socket?.send(jsonMessage(trickleMessage))
    }
    func subscriberCreateHandle(feed: Int, display: String) {
        let transaction = randomStringWithLength(len: 12)
        let jt = JanusTransaction()
        jt.tid = transaction
        //        et handle = JanusHandle()
        //        handle.handleId = (data?["data", default: "id"] as! Int);//warning
        //        handle.onJoined = { handle in
        //            self.delegate!.onPublisherJoined(handleId: ((handle!.handleId)! as NSNumber))
        //            self.publisherJoinRoom(handle: handle!)
        jt.success = { data in
            let handle = JanusHandle()
            handle.handleId = data?["data"]!["id"] as? Int//warning
            handle.feedId = feed
            handle.display = display
            handle.onRemoteJsep = { handle, jsep in
                self.delegate!.subscriberHandleRemoteJsep(handleId: handle!.handleId, dict: jsep!)
            }
            handle.onLeaving = { handle in
                self.subscriberOnLeaving(handle: handle!)
            }
            self.handleDict[handle.handleId] = handle
            self.feedDict[handle.handleId] = handle
            self.subscriberJoinRoom(handle: handle)
        }
        jt.error = { data in
        }
        transDict[transaction] = jt
        let attachMessage = [
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "transaction": transaction,
            "session_id": sessionId ?? 0,
            ] as [String : AnyObject]
        socket?.send(jsonMessage(attachMessage))
    }
    func subscriberJoinRoom(handle: JanusHandle) {
        let transaction = randomStringWithLength(len: 12)
        transDict[transaction] = "subscriber" as AnyObject
        let body = [
            "request": "join",
            "room": 1234, //[NSNumber numberWithInteger:room],
            "ptype": "listener",
            "feed": handle.feedId ?? 0,
            ] as [String : AnyObject]
        let message = [
            "janus": "message",
            "transaction": transaction,
            "session_id": sessionId ?? 0,
            "handle_id": handle.handleId ?? 0,
            "body": body,
        ] as [String: AnyObject]
        socket?.send(jsonMessage(message))
    }
    func subscriberCreateAnswer(_ handleId: Int?, sdp: RTCSessionDescription?) {
        let transaction = randomStringWithLength(len: 12)
//        let body = [
//            "request": "start",
//            "room": 1234, //[NSNumber numberWithInteger:room],
//        ] as [String: AnyObject]
        let body = ["request": "start", "room": 1234] as [String : AnyObject]
//        let type = RTCSessionDescription.string(for: (sdp?.type)!)
        var type: String? = nil
        if let aType = sdp?.type {
            type = RTCSessionDescription.string(for: aType)
        }
        
//        let jsep =  [
//            "type": type,
//            "sdp": [sdp: sdp],
//            ] as [String : AnyObject]
        var jsep: [String: AnyObject]? = nil
        if let aSdp = sdp?.sdp {
            jsep = ["type": type, "sdp": aSdp] as [String : AnyObject]
        }
//        let offerMessage = [
//            "janus": "message",
//            "body": body,
//            "jsep": jsep,
//            "transaction": transaction,
//            "session_id": sessionId ?? 0,
//            "handle_id": handleId ?? 0,
//            ] as [String : AnyObject]
        var offerMessage: [String: AnyObject]? = nil
        if let aJsep = jsep, let anId = handleId {
            offerMessage = ["janus": "message",
                            "body": body,
                            "jsep": aJsep,
                            "transaction": transaction,
                            "session_id": sessionId ?? 0,
                            "handle_id": anId] as [String : AnyObject]
        }
        socket?.send(jsonMessage(offerMessage))
    }
    func subscriberOnLeaving(handle: JanusHandle) {
        let transaction = randomStringWithLength(len: 12)
        let jt = JanusTransaction()
        jt.tid = transaction
        jt.success = { data in
            self.delegate?.onLeaving(handleId: handle.handleId)
            self.handleDict.removeValue(forKey: handle.handleId)
            self.feedDict.removeValue(forKey: handle.feedId)
        }
        jt.error =  { data in }
        transDict[transaction] = jt
        let message = [
            "janus": "detach",
            "transaction": transaction,
            "session_id": sessionId ?? 0,
            "handle_id": handle.handleId ?? 0,
        ] as [String:  AnyObject]
        socket?.send(jsonMessage(message))
    }
    @objc func keepAlive() {
        let dict = [ "janus": "keepalive", "session_id": sessionId ?? 0, "transaction": randomStringWithLength(len: 12)] as [String : AnyObject]
        socket?.send(jsonMessage(dict))
    }
    func jsonMessage(_ dict: [String: AnyObject]?) -> String {
        var message: Data? = nil
        if let aDict = dict {
            message = try? JSONSerialization.data(withJSONObject: aDict, options: .prettyPrinted)
        }
        var messageString: String? = nil
        if let aMessage = message {
            messageString = String(data: aMessage, encoding: .utf8)
        }
        
        print("====onGoingMessage=\(messageString ?? "")")
        return messageString!
    }
//    func jsonMessage(dict: [String: AnyObject]) -> String {
//        let message: Data? = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
//        let messageString = String(data: message!, encoding: .utf8)
//        print("====onGoingMessage=\(messageString ?? "goingMessageNull")")
//        //print("====onGoingMessage=\(String(describing: messageString))")
//        return messageString!
//    }
    
}
protocol WebSocketDelegate {
    //    - (void)onPublisherJoined:(NSNumber *)handleId;
    //    - (void)onPublisherRemoteJsep:(NSNumber *)handleId dict:(NSDictionary *)jsep;
    //    - (void): (NSNumber *)handleId dict:(NSDictionary *)jsep;
    //    - (void)subscriberHandleRemoteJsep: (NSNumber *)handleId dict:(NSDictionary *)jsep;
    //    - (void)onLeaving:(NSNumber *)handleId;
    func onPublisherJoined(handleId: Int?)
    func onPublisherRemoteJsep(handleId: Int?, dict jsep: [String: AnyObject])
    func subscriberHandleRemoteJsep(handleId: Int?, dict jsep: [String: AnyObject])
    func onLeaving(handleId: Int?)
    
}
enum ARDSignalingChannelState: Int {
    case kARDSignalingChannelStateClosed
    case kARDSignalingChannelStateOpen
    case kARDSignalingChannelStateCreate
    case kARDSignalingChannelStateAttach
    case kARDSignalingChannelStateJoin
    case kARDSignalingChannelStateOffer
    case kARDSignalingChannelStateError
}
