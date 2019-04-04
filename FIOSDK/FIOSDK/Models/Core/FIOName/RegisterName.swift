//
//  RegisterName.swift
//  FIOSDK
//
//  Created by Vitor Navarro on 2019-04-04.
//  Copyright © 2019 Dapix, Inc. All rights reserved.
//

import Foundation

internal struct RegisterName: Codable {
    
    let fioName:String
    let actor:String
    
    enum CodingKeys: String, CodingKey {
        case fioName = "fioname"
        case actor = "actor"
    }
    
}
