//
//  PublicAddressesResponse.swift
//  FIOSDK
//
//  Created by Leo on 2021/12/21.
//  Copyright © 2021 Dapix, Inc. All rights reserved.
//

import Foundation

extension FIOSDK.Responses {

    
    /// Structure used as response body for getPublicAddress
    public struct PublicAddressesResponse: Codable {
        
        /// public address for the specified FIO Address.
        public let publicAddresses: [OtherPublicAddressResponse]
        
        enum CodingKeys: String, CodingKey{
            case publicAddresses = "public_addresses"
        }
    }
    
    

}
