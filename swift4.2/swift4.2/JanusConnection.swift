//
//  JanusConnection.swift
//  Swift4
//
//  Created by macOS on 23.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//

import Foundation
import WebRTC

class JanusConnection {
    var handleId: Int?
    var connection: RTCPeerConnection?
    var videoTrack: RTCVideoTrack?
    var videoView: RTCEAGLVideoView?

    init(with handleId:Int) {
        self.handleId = handleId
    }
}
