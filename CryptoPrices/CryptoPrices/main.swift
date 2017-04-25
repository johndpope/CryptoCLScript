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

let coinbaseEndpoint = "https://api.coinbase.com/v2/prices/"
let coinbaseEndpointSuffix = "/spot"
var prices = [String : String]()

func makeNetworkCall(crypto: String, fiat: String = "USD") {
    let endpoint = coinbaseEndpoint + crypto.uppercased() + "-" + fiat.uppercased() + coinbaseEndpointSuffix

    if let endpointURL = URL(string: endpoint) {
        var request = URLRequest(url: endpointURL)
        request.addValue("2017-04-25", forHTTPHeaderField: "CB-VERSION")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in

            guard error == nil else {
                print("Error occured: \(error!.localizedDescription)")
                return
            }

            guard let validData = data else {
                print("Data is not valid: \(String(describing: data)), \nResponse: \(String(describing: response))")
                return
            }

            do {
                if let rawData = try JSONSerialization.jsonObject(with: validData, options: .allowFragments) as? [String: Any] {

                    guard let data = rawData["data"] as? [String: String] else {
                        print("Error, rawData is not in correct format: \(rawData)")
                        return
                    }

                    guard let price = data["amount"] else {
                        print("Error, couldn't find 'price' in \(data)")
                        return
                    }

                    var percentageChange = ""
                    if let previousPrice = readFromFile(crypto: crypto, fiat: fiat), let currentPrice = Double(price) {
                        let percentage = round(((1 - (currentPrice/previousPrice)) * 100)*1000)/1000
                        percentageChange = " (\(percentage)% since last update)"
                    }

                    let text = "1 \(crypto) = \(price) \(fiat)"
                    print(text  + percentageChange)
                    saveToFiles(crypto: crypto, fiat: fiat, text: text)
                }
            } catch let jsonError {
                print("Error in JSONSerialization: \(jsonError.localizedDescription)")
            }

            sempahore.signal()
        }

        task.resume()
        sempahore.wait()
    }
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

print("\nCurrent spot prices")
print("===================")
makeNetworkCall(crypto: "ETH")
makeNetworkCall(crypto: "BTC")
print("\n")
