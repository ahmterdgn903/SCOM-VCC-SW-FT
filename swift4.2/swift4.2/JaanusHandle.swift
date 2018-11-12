//
//  JaanusHandle.swift
//  Swift4
//
//  Created by macOS on 23.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//

import Foundation
import WebRTC

typealias OnJoined = (JanusHandle?) -> Void
typealias OnRemoteJsep = (JanusHandle?, [String : AnyObject]?) -> Void

class JanusHandle {
    var handleId: Int?
    var feedId: Int?
    var display = ""
    var onJoined: OnJoined?
    var onRemoteJsep: OnRemoteJsep?
    var onLeaving: OnJoined?
}
