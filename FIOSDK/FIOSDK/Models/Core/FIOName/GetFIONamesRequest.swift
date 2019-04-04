//
//  GetFioNamesRequest.swift
//  FIOSDK
//
//  Created by Vitor Navarro on 2019-04-04.
//  Copyright © 2019 Dapix, Inc. All rights reserved.
//

import Foundation

internal struct GetFIONamesRequest: Codable {
    
    public let fioPubAddress: String
    
    enum CodingKeys: String, CodingKey {
        case fioPubAddress = "fio_pub_address"
    }
    
}
