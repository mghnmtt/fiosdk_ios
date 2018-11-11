//
//  Requests.swift
//  FIOSDK
//
//  Created by shawn arney on 11/6/18.
//  Copyright © 2018 Dapix, Inc. All rights reserved.
//

import Foundation

//fio.finance for request flow private/public

public class RequestFunds{
    
    private func getURI() -> String {
        return Utilities.sharedInstance().URL
    }
    
    private func fioFinanceAccount() -> String {
        return "fio.finance"
    }
    
    private func fioFinanceAccountPrivateKey() -> String {
        return FIOSDK.sharedInstance().getSystemPrivateKey()
    }
    
    private func privateKey() -> String {
        return FIOSDK.sharedInstance().getPrivateKey()
    }
    
    struct TableRequest: Codable {
        let json: Bool
        let code: String
        let scope: String
        let table: String
        let table_key: String
        let lower_bound: String
        let upper_bound: String
        let limit: Int
        let key_type: String
        let index_position: String
        let encode_type: String
    }

    struct PendingHistoryResponse: Codable {
        let json: Bool
        let code: String
        let scope: String
        let table: String
        let table_key: String
        let lower_bound: String
        let limit: Int
        let key_type: String
        let index_position: String
        let encode_type: String
    }
    
    struct HistoryResponseDetails: Codable {
        let rows:[HistoryResponseDetailsRecord]
        let more: Bool
    }
    
    struct HistoryResponseDetailsRecord: Codable {
        let requestid: Int
        let fioappid: Int
        let originator: String
        let receiver: String
    }
    
    struct ResponseDetailsRecord: Codable {
        let fioappid: Int
        let originator: String
        let receiver: String
        let chain: String
        let asset: String
        let quantity: String
    }
    
    struct ResponseDetailsRecordReturned: Codable {
        let fioappid: Int
        let originator: String
        let receiver: String
        let chain: String
        let asset: String
        let quantity: String
        let originatorFioName: String
        let receiverFioName: String
    }
    
    public func getRequesteePendingHistoryByAddress (address:String, currencyCode:String, maxItemsReturned:Int, completion: @escaping ( _ requests:[FIOSDK.Request] , _ error:FIOError?) -> ()) {
        FIOSDK.sharedInstance().getFioNameByAddress(publicAddress: address, currencyCode: currencyCode) { (response, error) in
            if (error?.kind == FIOError.ErrorKind.Success){
                self.getRequesteePendingHistoryByFioName(fioName: response.name
                    , maxItemsReturned: maxItemsReturned
                    , completion: { (responses, err) in
                        completion(responses,err)
                })
            }
            else {
                completion([FIOSDK.Request](),error)
            }
        }
    }
    
    public func getRequesteePendingHistoryByFioName (fioName:String, maxItemsReturned:Int, completion: @escaping ( _ requests:[FIOSDK.Request] , _ error:FIOError?) -> ()) {
        FIOSDK.sharedInstance().getAddressByFioName(fioName: fioName, currencyCode: "FIO") { (response, error) in
            if (error?.kind == FIOError.ErrorKind.Success){
                self.getRequesteePendingHistory(requesteeAccountName: response.address, maxItemsReturned: maxItemsReturned
                    , completion: { (responses, err) in
                    
                        if (err?.kind == FIOError.ErrorKind.Success){
                            completion(responses, err)
                        }
                        else{
                            completion([FIOSDK.Request](),error)
                        }
                })
            }
            else {
                completion([FIOSDK.Request](),error)
            }
        }
    }
    
    public func getRequesteePendingHistory (requesteeAccountName:String, maxItemsReturned:Int, completion: @escaping ( _ requests:[FIOSDK.Request] , _ error:FIOError?) -> ()) {
        
        let fioRequest = TableRequest(json: true, code: "fio.finance", scope: "fio.finance", table: "pendrqsts", table_key: "", lower_bound: "", upper_bound: requesteeAccountName, limit: maxItemsReturned, key_type: "name", index_position: "3", encode_type: "dec")
        var jsonData: Data
        var jsonString: String
        do{
            jsonData = try JSONEncoder().encode(fioRequest)
            jsonString = String(data: jsonData, encoding: .utf8)!
            print(jsonString)
        }catch {
            completion ([FIOSDK.Request](), FIOError(kind: .NoDataReturned, localizedDescription: "Input Data, unable to JSON encode"))
            return
        }
        
        // create post request
        let url = URL(string: getURI() + "/chain/get_table_rows")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("no-cache", forHTTPHeaderField: "cache-control")
        
        // insert json data to the request
        request.httpBody = jsonString.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                
                completion([], FIOError(kind: .NoDataReturned, localizedDescription: ""))
                return
            }
            do {
                //fioResponse = try JSONDecoder().decode(PendingHistoryResponse.self, from: data)
                let result = String(data: data, encoding: String.Encoding.utf8) as String!
                print(result)
                print ("data was printed")
                let response = try JSONDecoder().decode(HistoryResponseDetails.self, from: data)
                print ("***")
                print (response)
                print ("****")
             
                if (response.rows.count > 0){
              
                    let dispatchGroup = DispatchGroup()
                    var detailRecords = SynchronizedArray<ResponseDetailsRecordReturned>()
                    ///TODO: do this with some sort of bounds to minimize calls - no time left to do this right
                    for item in response.rows.filter({ $0.receiver ==  requesteeAccountName}){
                        dispatchGroup.enter()
                        self.getRequestDetails(appIdStart: item.fioappid, appIdEnd: item.fioappid, maxItemsReturned: 1, completion: { (details, error) in
                            if (error?.kind == FIOError.ErrorKind.Success){
                                for detailItem in details.rows{
                                    detailRecords.append(newElement: detailItem)
                                }
                            }
                            dispatchGroup.leave()
                        })
                    }
                    
                    var dateMemoRecords = SynchronizedArray<ResponseRequestMemoDate>()
                    for item in response.rows.filter({ $0.receiver ==  requesteeAccountName}){
                        dispatchGroup.enter()
                        self.getRequestMemoDate(appIdStart: item.fioappid, appIdEnd: item.fioappid, type: 1, status: 1, maxItemsReturned: 100, completion: { (results, error) in
                            if (error?.kind == FIOError.ErrorKind.Success){
                                for memoItem in results{
                                    dateMemoRecords.append(newElement: memoItem)
                                    print("found a memo")
                                }
                            }
                            dispatchGroup.leave()
                        })
                    }
                    
                    dispatchGroup.notify(queue: DispatchQueue.main) {
                        
                        print("start maping")
                        // map the records here.
                        var arr = [FIOSDK.Request]()
                        for i in 0 ..< detailRecords.count {
                            let detail = detailRecords[i]
                            
                            let responseRow = response.rows.first(where:{$0.fioappid == detail.fioappid})
                            
                            var date:Int = 0
                            var memo:String = ""
                            for t in 0 ..< dateMemoRecords.count{
                                let dateItem = dateMemoRecords[t]
                                if (dateItem.fioappid == detail.fioappid){
                                    date = dateItem.time
                                    memo = dateItem.memo
                                    print("**found memo match")
                                }
                            }
                           
                           if (detail.asset.lowercased() != "fio"){
                                print ("*adding")
                                arr.append(FIOSDK.Request(amount: Float(detail.quantity) ?? 0, currencyCode: detail.asset, status: FIOSDK.RequestStatus.Requested, requestTimeStamp:date, requestDate: self.dateFromTimeStamp(time: date), requestDateFormatted: self.formattedDate(time: date),fromFioName: detail.originatorFioName, toFioName: detail.receiverFioName, requestorAccountName: detail.originator, requesteeAccountName: detail.receiver, memo: memo, fioappid: detail.fioappid, requestid: responseRow?.requestid ??  0, statusDescription: FIOSDK.RequestStatus.Requested.rawValue))
                           }

                        }

                        completion(arr, FIOError.init(kind: FIOError.ErrorKind.Success, localizedDescription: ""))
                    }
                    
                }
                else{
                    completion([], FIOError(kind: .Success, localizedDescription: ""))
                }
                
            }catch let error{
                let err = FIOError(kind: .Failure, localizedDescription: error.localizedDescription)///TODO:create this correctly with ERROR results
                completion([], err)
            }
        }
        
        task.resume()
    }
    
    private func dateFromTimeStamp(time:Int) -> Date {
        let index = Double(time)
        let date = NSDate(timeIntervalSince1970: index ?? 11111111)
        return date as Date
    }
    
    private func formattedDate(time:Int) -> String {
        let dateFormatterPrint = DateFormatter()
        dateFormatterPrint.dateFormat = "MMM dd,yyyy"
    
        return dateFormatterPrint.string(from: dateFromTimeStamp(time:time))
    }
    
    struct ResponseDetails: Codable {
        let rows:[ResponseDetailsRecord]
    }
    
    struct ResponseDetailsReturned: Codable {
        let rows:[ResponseDetailsRecordReturned]
    }
    
    private struct FioName{
        let fioName: String
        let address: String
    }
    
    private func getRequestDetails (appIdStart:Int, appIdEnd:Int, maxItemsReturned:Int, completion: @escaping ( _ requests:ResponseDetailsReturned , _ error:FIOError?) -> ()) {
        
        let fioRequest = TableRequest(json: true, code: "fio.finance", scope: "fio.finance", table: "trxcontexts", table_key: "", lower_bound: String(appIdStart),
                                      upper_bound: String(appIdEnd+1), limit: maxItemsReturned, key_type: "", index_position: "", encode_type: "dec")
        var jsonData: Data
        var jsonString: String
        do{
            jsonData = try JSONEncoder().encode(fioRequest)
            jsonString = String(data: jsonData, encoding: .utf8)!
            print(jsonString)
        }catch {
            completion (ResponseDetailsReturned(rows: [RequestFunds.ResponseDetailsRecordReturned]()), FIOError(kind: .Failure, localizedDescription: "Json Encoding of input data failed."))
            return
        }
        
        // create post request
        let url = URL(string: getURI() + "/chain/get_table_rows")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("no-cache", forHTTPHeaderField: "cache-control")
        
        // insert json data to the request
        request.httpBody = jsonString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                
                completion(ResponseDetailsReturned(rows: []), FIOError(kind: .NoDataReturned, localizedDescription: ""))
                return
            }
            do {
               
                let result = String(data: data, encoding: String.Encoding.utf8) as String!
                print(result)
                print ("getRequestDetails() data was printed")
                let response = try JSONDecoder().decode(ResponseDetails.self, from: data)
                print ("*****")
                print (response)
                print ("***")
  
                if (response.rows.count < 1){
                    completion(ResponseDetailsReturned(rows: []), FIOError(kind: .NoDataReturned, localizedDescription: ""))
                    return
                }
                print(response.rows.count)
                let dispatchGroup = DispatchGroup()
                var fioNameRecords = SynchronizedArray<FioName>()
                ///TODO: do this with some sort of bounds to minimize calls - no time left to do this right
                for item in response.rows{
                    print("dispatch")
                    dispatchGroup.enter()
                    FIOSDK.sharedInstance().getFioNameByAddress(publicAddress: item.receiver, currencyCode: item.chain, completion: { (res, err) in
                        if (err?.kind == FIOError.ErrorKind.Success){
                            fioNameRecords.append(newElement: FioName(fioName: res.name, address: item.receiver) )
                        }
                        else {
                            fioNameRecords.append(newElement: FioName(fioName: "not found", address: item.receiver) )
                        }
                        dispatchGroup.leave()
                    })
                }
                
                for item in response.rows{
                    print("dispatch2")
                    dispatchGroup.enter()
                    FIOSDK.sharedInstance().getFioNameByAddress(publicAddress: item.originator, currencyCode: item.chain, completion: { (res, err) in
                        if (err?.kind == FIOError.ErrorKind.Success){
                            fioNameRecords.append(newElement: FioName(fioName: res.name, address: item.originator) )
                        }
                        else {
                            fioNameRecords.append(newElement: FioName(fioName: "not found", address: item.originator) )
                        }
                        dispatchGroup.leave()
                    })
                }
                
                ///TODO: do this the right way -- right now, we know there is only one record.
                dispatchGroup.notify(queue: DispatchQueue.main) {
                    print("dispatch group main")
                    var arr = [ResponseDetailsRecordReturned]()
                    for item in response.rows{
                        // let responseRow = response.rows.first(where:{$0.fioappid == detail.fioappid})
                       //let fioName:FioName = fioNameRecords.first(where:{$0.address == item.receiver})
                        var receiverFioName = ""
                        for i in 0 ..< fioNameRecords.count {
                            let fioName = fioNameRecords[i]
                            if (fioName.address == item.receiver){
                                receiverFioName = fioName.fioName
                                break
                            }
                        }
                        
                        var originatorFioName = ""
                        for i in 0 ..< fioNameRecords.count {
                            let fioName = fioNameRecords[i]
                            if (fioName.address == item.originator){
                                originatorFioName = fioName.fioName
                                break
                            }
                        }
                        
                        arr.append(ResponseDetailsRecordReturned(fioappid: item.fioappid, originator: item.originator, receiver: item.receiver, chain: item.chain, asset: item.asset, quantity: item.quantity, originatorFioName: originatorFioName, receiverFioName: receiverFioName))
                    }
                    completion(ResponseDetailsReturned(rows: arr), FIOError(kind: .Success, localizedDescription: ""))
                }
            }catch let error{
                let err = FIOError(kind: .Failure, localizedDescription: error.localizedDescription)///TODO:create this correctly with ERROR results
                completion(ResponseDetailsReturned(rows: []), err)
            }
        }
        
        task.resume()
    }

    struct RequestTrxLogDetails: Codable {
        let rows:[RequestTrxLog]
        let more:Bool
    }
    
    struct RequestTrxData: Codable{
        let reqid: String?
        let obtid: String?
        let memo: String
    }
    
    struct RequestTrxLog: Codable{
        let key: Int
        let fioappid: Int
        let type: Int
        let status: Int
        let time: Int
        let data: String
    }
    
    struct ResponseRequestMemoDate{
        let fioappid: Int
        let time: Int
        let memo: String
    }

    ///TODO: get the bounds working, to restrict the data
    private func getRequestMemoDate (appIdStart:Int, appIdEnd:Int, type:Int, status:Int, maxItemsReturned:Int, completion: @escaping ( _ requests:[ResponseRequestMemoDate] , _ error:FIOError?) -> ()) {
        
        let fioRequest = TableRequest(json: true, code: "fio.finance", scope: "fio.finance", table: "trxlogs", table_key: "", lower_bound: "",
                                      upper_bound: "", limit: maxItemsReturned, key_type: "", index_position: "", encode_type: "dec")
        var jsonData: Data
        var jsonString: String
        do{
            jsonData = try JSONEncoder().encode(fioRequest)
            jsonString = String(data: jsonData, encoding: .utf8)!
            print(jsonString)
        }catch {
            completion ([ResponseRequestMemoDate](), FIOError(kind: .NoDataReturned, localizedDescription: ""))
            return
        }
        
        // create post request
        let url = URL(string: getURI() + "/chain/get_table_rows")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("no-cache", forHTTPHeaderField: "cache-control")
        
        // insert json data to the request
        request.httpBody = jsonString.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                
                completion([ResponseRequestMemoDate](), FIOError(kind: .NoDataReturned, localizedDescription: ""))
                return
            }
            do {
                
                let result = String(data: data, encoding: String.Encoding.utf8) as String!
                print(result)
                print ("getRequestMemoDate() data was printed")
                let response = try JSONDecoder().decode(RequestTrxLogDetails.self, from: data)
                print ("*****")
                print (response)
                print ("***")
                
                if (response.rows.count < 1){
                    completion([ResponseRequestMemoDate](), FIOError(kind: .NoDataReturned, localizedDescription: ""))
                    return
                }

                for row in response.rows {
                    if (row.fioappid == appIdStart && row.type == type){
                        print("MEMO MATCHED")
                        // let memo = try JSONDecoder().decode(RequestTrxLogDetails.self, from: row.data)
                        let jsonDecoder = JSONDecoder()
                        let datafield = try jsonDecoder.decode(RequestTrxData.self, from: row.data.data(using: .utf8)!)
                       
                        completion([ResponseRequestMemoDate(fioappid: row.fioappid, time: row.time, memo: datafield.memo)], FIOError(kind: .Success, localizedDescription: ""))
                        return
                    }
                }
                completion([ResponseRequestMemoDate](), FIOError(kind: .NoDataReturned, localizedDescription: ""))
                
            }catch let error{
                let err = FIOError(kind: .Failure, localizedDescription: error.localizedDescription)///TODO:create this correctly with ERROR results
                completion([ResponseRequestMemoDate](), err)
            }
        }
        
        task.resume()
    }
    
    struct RequestFundsData: Codable {
        let requestid: Int
        let requestor: String
        let requestee: String
        let chain: String
        let asset: String
        let quantity: Float
        let memo: String
    }

    // the private key is associated with the account: name
    public func requestFunds (requestorAccountName:String, requestId: Int, requesteeAccountName:String, chain:String , asset:String, amount:Float, memo:String, completion: @escaping ( _ error:FIOError?) -> ()) {
        
        var privateKey = self.fioFinanceAccountPrivateKey()  // So, the accounts are being created with the FIO.system private key... will it work if we USE FIO.system privatekey HERE
        if (requestorAccountName == "fioname22222"){
            privateKey = "5JA5zQkg1S59swPzY6d29gsfNhNPVCb7XhiGJAakGFa7tEKSMjT"
        }
        
        let importedPk = try! PrivateKey(keyString: privateKey)
        
        let data = RequestFundsData(requestid: requestId, requestor: requestorAccountName, requestee: requesteeAccountName, chain: chain, asset: asset, quantity: amount, memo: memo)
        
        var jsonString: String
        do{
            let jsonData:Data = try JSONEncoder().encode(data)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch {
            completion (FIOError(kind: .Failure, localizedDescription: "Json Encoding of input failed"))
            return
        }
        
        let abi = try! AbiJson(code: fioFinanceAccount(), action: "requestfunds", json:jsonString)
        
        TransactionUtil.pushTransaction(abi: abi, account: requestorAccountName, privateKey: importedPk!, completion: { (result, error) in
            if error != nil {
                if (error! as NSError).code == RPCErrorResponse.ErrorCode {
                    let errDescription = "error"
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                } else {
                    let errDescription = ("other error: \(String(describing: error?.localizedDescription))")
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                }
            } else {
                print("Ok. Request Funds, Txid: \(result!.transactionId)")
                completion(FIOError.init(kind: FIOError.ErrorKind.Success, localizedDescription: ""))
            }
        })
    }
    
    struct RejectFundsData: Codable {
        let fioappid: Int
        let requestee: String
        let memo: String
    }
    
    //THE PRIVATE KEY is associated with the account: name --> so, need to tie it back into.. the account creation side of things.
    
    public func rejectFundsRequest (requesteeAccountName:String, fioAppId:Int, memo:String, completion: @escaping ( _ error:FIOError?) -> ()) {
        
        var privateKey = self.fioFinanceAccountPrivateKey()  // So, the accounts are being created with the FIO.system private key... will it work if we USE FIO.system privatekey HERE
        if (requesteeAccountName == "fioname22222"){
            privateKey = "5JA5zQkg1S59swPzY6d29gsfNhNPVCb7XhiGJAakGFa7tEKSMjT"
        }
        
        let importedPk = try! PrivateKey(keyString: privateKey)
        
        let data = RejectFundsData(fioappid: fioAppId, requestee: requesteeAccountName, memo: memo)
        
        var jsonString: String
        do{
            let jsonData:Data = try JSONEncoder().encode(data)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch {
            completion (FIOError(kind: .Failure, localizedDescription: "Json Encoding of input data failed."))
            return
        }
        print(jsonString)
        
        let abi = try! AbiJson(code: fioFinanceAccount(), action: "rejectrqst", json:jsonString)
        
        TransactionUtil.pushTransaction(abi: abi, account: requesteeAccountName, privateKey: importedPk!, completion: { (result, error) in
            if error != nil {
                if (error! as NSError).code == RPCErrorResponse.ErrorCode {
                    let errDescription = "error"
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                } else {
                    let errDescription = ("other error: \(String(describing: error?.localizedDescription))")
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                }
            } else {
                print("Ok. reject funds successful, Txid: \(result!.transactionId)")
                completion(FIOError.init(kind: FIOError.ErrorKind.Success, localizedDescription: ""))
            }
        })
    }
  
    struct CancelFundsData: Codable {
        let requestid: Int
        let requestor: String
        let memo: String
    }
    
    public func cancelFundsRequest (requestorAccountName:String, requestId:Int, memo:String, completion: @escaping ( _ error:FIOError?) -> ()) {
        var privateKey = self.fioFinanceAccountPrivateKey()  // So, the accounts are being created with the FIO.system private key... will it work if we USE FIO.system privatekey HERE
        if (requestorAccountName == "fioname22222"){
            privateKey = "5JA5zQkg1S59swPzY6d29gsfNhNPVCb7XhiGJAakGFa7tEKSMjT"
        }
        
        let importedPk = try! PrivateKey(keyString: privateKey)
        
        let data = CancelFundsData(requestid: requestId, requestor: requestorAccountName, memo: memo)
        
        var jsonString: String
        do{
            let jsonData:Data = try JSONEncoder().encode(data)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch {
            completion (FIOError(kind: .Failure, localizedDescription: "JSon encoding of input data failed."))
            return
        }
        print(jsonString)
        
        let abi = try! AbiJson(code: fioFinanceAccount(), action: "cancelrqst", json:jsonString)
        
        TransactionUtil.pushTransaction(abi: abi, account: requestorAccountName, privateKey: importedPk!, completion: { (result, error) in
            if error != nil {
                if (error! as NSError).code == RPCErrorResponse.ErrorCode {
                    let errDescription = "error"
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                } else {
                    let errDescription = ("other error: \(String(describing: error?.localizedDescription))")
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                }
            } else {
                print("Ok. cancel funds successful, Txid: \(result!.transactionId)")
                 completion(FIOError.init(kind: FIOError.ErrorKind.Success, localizedDescription: ""))
            }
        })
    }
    
    struct ApproveFundsData: Codable {
        let fioappid: Int
        let requestee: String
        let obtid:String
        let memo: String
    }
    
    //THE PRIVATE KEY is associated with the account: name --> so, need to tie it back into.. the account creation side of things.
    // reportrqst '{"fioappid": "2","requestee":"fioname22222","obtid":"0x123456789","memo":"approved"}' --permission fioname22222@active
    public func approveFundsRequest (requesteeAccountName:String, fioAppId:Int, obtid:String, memo:String, completion: @escaping ( _ error:FIOError?) -> ()) {
        var privateKey = self.privateKey()  // So, the accounts are being created with the FIO.system private key... will it work if we USE FIO.system privatekey HERE
        if (requesteeAccountName == "fioname22222"){
            privateKey = "5JA5zQkg1S59swPzY6d29gsfNhNPVCb7XhiGJAakGFa7tEKSMjT"
        }
        
        let importedPk = try! PrivateKey(keyString: privateKey)
        
        let data = ApproveFundsData(fioappid: fioAppId, requestee: requesteeAccountName, obtid:obtid, memo: memo)
        
        var jsonString: String
        do{
            let jsonData:Data = try JSONEncoder().encode(data)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch {
            completion (FIOError(kind: .Failure, localizedDescription: "Json encoding of input data failed."))
            return
        }
        print(jsonString)
        
        let abi = try! AbiJson(code: fioFinanceAccount(), action: "reportrqst", json:jsonString)
        
        TransactionUtil.pushTransaction(abi: abi, account: requesteeAccountName, privateKey: importedPk!, completion: { (result, error) in
            if error != nil {
                if (error! as NSError).code == RPCErrorResponse.ErrorCode {
                    let errDescription = "error"
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                } else {
                    let errDescription = ("other error: \(String(describing: error?.localizedDescription))")
                    print (errDescription)
                    completion(FIOError.init(kind: FIOError.ErrorKind.Failure, localizedDescription: errDescription))
                }
            } else {
                print("Ok. reject funds successful, Txid: \(result!.transactionId)")
                completion(FIOError.init(kind: FIOError.ErrorKind.Success, localizedDescription: ""))
            }
        })
    }
    
    
    public class SynchronizedArray<T> {
        private var array: [T] = []
        private let accessQueue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: .concurrent)
        
        public func append(newElement: T) {
            
            self.accessQueue.async(flags:.barrier) {
                self.array.append(newElement)
            }
        }
        
        public func removeAtIndex(index: Int) {
            
            self.accessQueue.async(flags:.barrier) {
                self.array.remove(at: index)
            }
        }
        
        public var count: Int {
            var count = 0
            
            self.accessQueue.sync {
                count = self.array.count
            }
            
            return count
        }
        
        public func first() -> T? {
            var element: T?
            
            self.accessQueue.sync {
                if !self.array.isEmpty {
                    element = self.array[0]
                }
            }
            
            return element
        }
        
        public subscript(index: Int) -> T {
            set {
                self.accessQueue.async(flags:.barrier) {
                    self.array[index] = newValue
                }
            }
            get {
                var element: T!
                self.accessQueue.sync {
                    element = self.array[index]
                }
                
                return element
            }
        }
    }
    
}
