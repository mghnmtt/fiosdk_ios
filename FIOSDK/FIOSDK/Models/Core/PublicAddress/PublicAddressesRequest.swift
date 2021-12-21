//
//  PublicAddressesRequest.swift
//  FIOSDK
//
//  Created by Leo on 2021/12/21.
//  Copyright © 2021 Dapix, Inc. All rights reserved.
//

import Foundation


internal struct PublicAddressesRequest: Codable {
    
    public let fioAddress: String
    
    enum CodingKeys: String, CodingKey{
        case fioAddress = "fio_address"

    }
    
}
