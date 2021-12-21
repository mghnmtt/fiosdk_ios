//
//  OtherPublicAddressResponse.swift
//  FIOSDK
//
//  Created by Leo on 2021/12/21.
//  Copyright © 2021 Dapix, Inc. All rights reserved.
//

import Foundation

public struct OtherPublicAddressResponse: Codable {
    
    /// public address for the specified FIO Address.
    public let publicAddress: String?
    public let chainCode: String?
    public let tokenCode: String?

    enum CodingKeys: String, CodingKey{
        case publicAddress = "public_address"
        case chainCode = "chain_code"
        case tokenCode = "token_code"

    }
}
