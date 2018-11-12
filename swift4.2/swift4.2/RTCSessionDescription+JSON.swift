//
//  RTCSessionDescription+JSON.swift
//  Swift4
//
//  Created by macOS on 23.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//
import Foundation
import WebRTC


private let kRTCSessionDescriptionTypeKey = "type"
private let kRTCSessionDescriptionSdpKey = "sdp"

extension RTCSessionDescription {
    convenience init(fromJSONDictionary dictionary: [String : AnyObject]?) {
        let typeString = dictionary?[kRTCSessionDescriptionTypeKey] as? String
        let type: RTCSdpType = RTCSessionDescription.type(for: typeString!)
        let sdp = dictionary?[kRTCSessionDescriptionSdpKey] as? String
        self.init(type: type, sdp: sdp!)
    }

    
    func jsonData() -> Data? {
        let type = RTCSessionDescription.string(for: self.type)
        let json = [kRTCSessionDescriptionTypeKey: type, kRTCSessionDescriptionSdpKey: sdp]
        return try? JSONSerialization.data(withJSONObject: json, options: [])
    }
}
