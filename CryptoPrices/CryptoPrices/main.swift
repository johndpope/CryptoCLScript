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
var prices = [String]()
var showCopyPasteFriendly = false

//
// MARK: - CommandLine argument parsing
//

let args = CommandLine.arguments
let flags = Array(args.dropFirst())
var continueExecution = true

for (index, flag) in flags.enumerated() {
    switch flag {
    case "-n":  showCopyPasteFriendly = true
    default:    break
    }
}

//
// MARK: - Data parsing
//

func makeNetworkCall(completion: @escaping ([String: String]) -> Void) {
    let endpoint = providerEndpoint + "?limit=100"

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

            do {
                if let rawData = try JSONSerialization.jsonObject(with: validData, options: .allowFragments) as? [[String: Any]] {

                    var cryptoPrices = [String: String]()

                    for entry in rawData {
                        guard let id = entry["id"] as? String, let price = entry["price_usd"] as? String else { break }
                        cryptoPrices[id] = price
                    }

                    completion(cryptoPrices)

                } else {
                    print("Error! Could not serialize data")
                    sempahore.signal()
                }

            } catch let jsonError {
                print("Error in JSONSerialization: \(jsonError.localizedDescription)")
                sempahore.signal()
            }

        }
        task.resume()
        sempahore.wait()
    }
}

func getPrices(forCryptos cryptos: [Crypto]) {

    makeNetworkCall() { cryptoPrices in

        for crypto in cryptos {
            guard let price = cryptoPrices[crypto.rawValue] else { continue }

            var percentageChange = ""
            if let previousPrice = readFromFile(crypto: "\(crypto)"), let currentPrice = Double(price) {
                let percentage = round((((currentPrice/previousPrice) - 1) * 100)*1000)/1000
                percentageChange = " (\(percentage)% since last update)"
            }

            let text = "1 \(crypto) = \(price) USD"
            print(text  + percentageChange)
            prices.append("\(price)")
            saveToFiles(crypto: "\(crypto)", text: text)
        }

        sempahore.signal()
    }
}

//
// Get the CryptoCL directory, or create it if it doesn't exist
//

func getDirectory() -> URL {

    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        fatalError("Something went wrong when trying to save files")
    }

    let directoryPathForCrypto = directory.appendingPathComponent("CryptoCL")

    // Used to create a directory if it doesn't already exist
    func createDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: directoryPathForCrypto.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error.localizedDescription)")
        }
    }

    var isDirectory: ObjCBool = false

    if FileManager.default.fileExists(atPath: directoryPathForCrypto.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
            return directoryPathForCrypto
        }
    }
    createDirectory()
    return directoryPathForCrypto
}

func saveToFiles(crypto: String, text: String) {
    let historicFile = "\(crypto)-USD-historic.txt"
    let recentFile = "\(crypto)-USD-recent.txt"

    // Write to the file in the directory
    func writeToFile(_ fileName: String) {
        let path = getDirectory().appendingPathComponent(fileName)
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

    writeToFile(recentFile)
    writeToFile(historicFile)
}

func readFromFile(crypto: String) -> Double? {
    let file = "\(crypto)-USD-recent.txt"

    let path = getDirectory().appendingPathComponent(file)

    do {
        let text = try String(contentsOf: path, encoding: .utf8)
        let pattern = "(= )(.*)( USD)"
        let regEx = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let extract = regEx.matches(in: text, options: [], range: NSMakeRange(0, text.utf8.count))

        // Get the price data from the first match
        let price = (text as NSString).substring(with: extract[0].rangeAt(2))
        return Double(price)
    } catch {}

    return nil
}

enum Crypto: String {
    case BTC = "bitcoin"
    case ETH = "ethereum"
    case LTC = "litecoin"
    case XLM = "stellar"
    case RLC = "rlc"
    case GNO = "gnosis-gno"
    case ANT = "aragon"
    case SJCX = "storjcoin-x"
    //case STORJ = "storj"
    case MYST = "mysterium"
    case PLBT = "polybius"
    case BNT = "bancor"

    // ***************************************************************
    // New values need to be inserted above + in allValues array below
    // ***************************************************************

    // You'll need to use the ID that Coinmarketcap uses.
    // E.g. In https://coinmarketcap.com/assets/gnosis-gno/,
    // the part after `assets` would be GNO's ID.

    static let allValues: [Crypto] = [.BTC, .ETH, .LTC, .XLM, .RLC, .GNO, .ANT, .SJCX, .MYST, .PLBT, .BNT]
}

print("\nCurrent spot prices")
print("===================")
getPrices(forCryptos: Crypto.allValues)
print("\n")

if showCopyPasteFriendly {
    print("Copy/paste friendly")
    print("===================")

    for price in prices {
        print(price)
    }
}
