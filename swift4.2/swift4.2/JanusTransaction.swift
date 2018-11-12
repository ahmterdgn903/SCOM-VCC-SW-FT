//
//  JanusTransaction.swift
//  Swift4
//
//  Created by macOS on 23.10.2018.
//  Copyright © 2018 erdogan. All rights reserved.
//

import Foundation

//typealias TransactionSuccessBlock = (NSDictionary) -> Void
//typealias TransactionErrorBlock = (NSDictionary) -> Void
typealias TransactionSuccessBlock = (_ data: [String : AnyObject]?) -> Void
typealias TransactionErrorBlock = (_ data: [String : AnyObject]?) -> Void

class JanusTransaction {
    var tid = ""
    var success: TransactionSuccessBlock?
    var error: TransactionErrorBlock?
}

