//
//  TransactionUtil.swift
//  SwiftyEOS
//
//  Created by croath on 2018/8/16.
//  Copyright © 2018 ProChain. All rights reserved.
//

import Foundation

@objcMembers class TransactionUtil: NSObject {
    static func pushTransaction(abi: AbiJson, account: String, pkString: String, completion: @escaping (_ result: TransactionResult?, _ error: Error?) -> ()) {
        guard let privateKey = try? PrivateKey(keyString: pkString) else {
            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "invalid private key"]))
            return
        }
        
        pushTransaction(abi: abi, account: account, privateKey: privateKey!, completion: completion)
    }
    
    static func pushTransaction(abi: AbiJson, account: String, privateKey: PrivateKey, completion: @escaping (_ result: TransactionResult?, _ error: Error?) -> ()) {
        EOSRPC.sharedInstance.chainInfo { (chainInfo, error) in
            if error != nil {
                completion(nil, error)
                return
            }
            EOSRPC.sharedInstance.getBlock(blockNumOrId: "\(chainInfo!.lastIrreversibleBlockNum)" as AnyObject, completion: { (blockInfo, error) in
                if error != nil {
                    completion(nil, error)
                    return
                }
                
                EOSRPC.sharedInstance.abiJsonToBin(abi: abi, completion: { (bin, error) in
                    if error != nil {
                        completion(nil, error)
                        return
                    }
                             
                    let auth = Authorization(actor: account, permission: "active")
                    var authorization:[Authorization] = [auth]
                    if (abi.code == FIOSDK.FIOSYSTEMCODE){
                    let authFioSystem = Authorization(actor: FIOSDK.FIOSYSTEMPRINCIPAL, permission: "active") //  authorization = [auth,authFioSystem]
                    }
                    
                    let action = Action(public_address: abi.code, name: abi.action, authorization:authorization, data: bin!.binargs)
                    let rawTx = Transaction(blockInfo: blockInfo!, actions: [action])
                    
                    var tx = PackedTransaction(transaction: rawTx, compression: "none")
                    if (abi.code == FIOSDK.FIOSYSTEMCODE){
                     //   tx.signatures = ["5KBX1dwHME4VyuUss2sYM25D5ZTDvyYrbEz37UJqwAVAsR4tGuY","5JA5zQkg1S59swPzY6d29gsfNhNPVCb7XhiGJAakGFa7tEKSMjT"]
                    }
                    
                    tx.sign(pk: privateKey, chainId: chainInfo!.chainId!)
                   
                    let signedTx = SignedTransaction(packedTx: tx)
                    EOSRPC.sharedInstance.pushTransaction(transaction: signedTx, completion: { (txResult, error) in
                        if error != nil {
                            completion(nil, error)
                            return
                        }
                        completion(txResult, nil)
                    })
                })
            })
        }
    }
    
    //TODO:Multiple action combinations
    static func pushTransaction(abis: [AbiJson], account: String, privateKey: PrivateKey, completion: @escaping (_ result: TransactionResult?, _ error: Error?) -> ()) {
        EOSRPC.sharedInstance.chainInfo { (chainInfo, error) in
            if error != nil {
                completion(nil, error)
                return
            }
            EOSRPC.sharedInstance.getBlock(blockNumOrId: "\(chainInfo!.lastIrreversibleBlockNum)" as AnyObject, completion: { (blockInfo, error) in
                if error != nil {
                    completion(nil, error)
                    return
                }
                var actions: [Action] = []
                let auth = Authorization(actor: account, permission: "active")
                
                let group = DispatchGroup()
                for i in 0..<abis.count {
                    let abi: AbiJson = abis[i] as AbiJson
                    let queueAbi = DispatchQueue(label: abi.action)
                    group.enter()
                    queueAbi.async(group: group) {
                        // action
                        EOSRPC.sharedInstance.abiJsonToBin(abi: abi, completion: { (bin, error) in
                            if error == nil && bin != nil {
                                let action = Action(public_address: abi.code,
                                                    name: abi.action, authorization: [auth], data: bin!.binargs)
                                actions.append(action)
                            }
                            group.leave()
                        })
                    }
                }
                
                group.notify(queue: DispatchQueue.main) {
                    // Finish
                    if actions.count == abis.count {
                        //actions sort by abis
                        var sortActions: [Action] = []
                        for i in 0..<abis.count {
                            let abi: AbiJson = abis[i] as AbiJson
                            for (_, item) in actions.enumerated() {
                                if item.name == abi.action {
                                    sortActions.append(item)
                                    break
                                }
                            }
                        }
                        let rawTx = Transaction(blockInfo: blockInfo!, actions: sortActions)
                        var tx = PackedTransaction(transaction: rawTx, compression: "none")
                        tx.sign(pk: privateKey, chainId: chainInfo!.chainId!)
                        let signedTx = SignedTransaction(packedTx: tx)
                        EOSRPC.sharedInstance.pushTransaction(transaction: signedTx, completion: { (txResult, error) in
                            if error != nil {
                                completion(nil, error)
                                return
                            }
                            completion(txResult, nil)
                        })
                    }else {
                        completion(nil, NSError(domain: errorDomain, code: RPCErrorResponse.ErrorCode, userInfo: [RPCErrorResponse.ErrorKey: "errorResponse"]))
                    }
                }
            })
        }
    }
}
