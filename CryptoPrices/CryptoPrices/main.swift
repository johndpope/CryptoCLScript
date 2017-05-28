#!/usr/bin/swift

//
//  main.swift
//  CryptoPrices
//
//  Created by David Truong on 25/4/17.
//
//

import Foundation

let sempahore = DispatchSemaphore(value: 0)

let providerEndpoint = "https://api.coinmarketcap.com/v1/ticker/"
var prices = [String : String]()

func makeNetworkCall(crypto: Crypto, fiat: String = "USD") {
    let endpoint = providerEndpoint + crypto.rawValue + "/?convert=" + fiat.uppercased()

    if let endpointURL = URL(string: endpoint) {
        let request = URLRequest(url: endpointURL)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            guard error == nil else {
                print("Error occured: \(error!.localizedDescription)")
                sempahore.signal()
                return
            }

            guard let validData = data else {
                print("Data is not valid: \(String(describing: data)), \nResponse: \(String(describing: response))")
                sempahore.signal()
                return
            }

            processData(data: validData, crypto: crypto, fiat: fiat)

        }
        task.resume()
        sempahore.wait()
    }
}

func processData(data: Data, crypto: Crypto, fiat: String) {

    do {
        if let rawData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: String]] {

            guard let price = rawData[0]["price_usd"] else {
                print("Error, couldn't find 'price' in \(data)")
                sempahore.signal()
                return
            }

            var percentageChange = ""
            if let previousPrice = readFromFile(crypto: "\(crypto)", fiat: fiat), let currentPrice = Double(price) {
                let percentage = round((((currentPrice/previousPrice) - 1) * 100)*1000)/1000
                percentageChange = " (\(percentage)% since last update)"
            }

            let text = "1 \(crypto) = \(price) \(fiat)"
            print(text  + percentageChange)
            saveToFiles(crypto: "\(crypto)", fiat: fiat, text: text)
        }
    } catch let jsonError {
        print("Error in JSONSerialization: \(jsonError.localizedDescription)")
        sempahore.signal()
    }

    sempahore.signal()
}

func saveToFiles(crypto: String, fiat: String, text: String) {
    let historicFile = "\(crypto)-\(fiat)-historic.txt"
    let recentFile = "\(crypto)-\(fiat)-recent.txt"

    func writeToFile(_ fileName: String) {
        if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let path = directory.appendingPathComponent(fileName)
            let stringToWrite = "\(Date()): \(text)"

            do {
                if let fileHandle = FileHandle(forWritingAtPath: path.path), fileName != recentFile {
                    defer { fileHandle.closeFile() }

                    fileHandle.seekToEndOfFile()
                    fileHandle.write(("\n" + stringToWrite).data(using: .utf8)!)
                } else {
                    try stringToWrite.write(to: path, atomically: false, encoding: .utf8)
                }
            } catch {
                print("Error saving to file: \(error.localizedDescription)")
            }
        }
    }

    writeToFile(recentFile)
    writeToFile(historicFile)
}

func readFromFile(crypto: String, fiat: String) -> Double? {
    let file = "\(crypto)-\(fiat)-recent.txt"
    if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

        let path = directory.appendingPathComponent(file)

        do {
            let text = try String(contentsOf: path, encoding: .utf8)
            let pattern = "(= )(.*)( USD)"
            let regEx = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let extract = regEx.matches(in: text, options: [], range: NSMakeRange(0, text.utf8.count))

            // Get the price data from the first match
            let price = (text as NSString).substring(with: extract[0].rangeAt(2))
            return Double(price)
        } catch {}
    }
    return nil
}

enum Crypto: String {
    case BTC = "bitcoin"
    case ETH = "ethereum"
    case XLM = "stellar"
    case RLC = "rlc"
    case GNO = "gnosis-gno"
    case ANT = "aragon"
    case SJCX = "storjcoin-x"
}

print("\nCurrent spot prices")
print("===================")
makeNetworkCall(crypto: .BTC)
makeNetworkCall(crypto: .ETH)
makeNetworkCall(crypto: .XLM)
makeNetworkCall(crypto: .RLC)
makeNetworkCall(crypto: .GNO)
makeNetworkCall(crypto: .ANT)
makeNetworkCall(crypto: .SJCX)
print("\n")
