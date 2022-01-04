//
//  PublicAddress.swift
//  FIOSDK
//
//  Created by Leo on 2021/12/22.
//  Copyright © 2021 Dapix, Inc. All rights reserved.
//

import Foundation

public struct PublicAddress: Codable {
    let chainCode: String
    let tokenCode: String
    let publicAddress: String
    
    public init(chainCode:String,tokenCode:String,publicAddress:String){
        self.chainCode = chainCode
        self.tokenCode = tokenCode
        self.publicAddress = publicAddress
    }
    
    
    enum CodingKeys: String, CodingKey {
        case chainCode = "chain_code"
        case tokenCode = "token_code"
        case publicAddress = "public_address"
    }
}
