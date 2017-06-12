# CryptoCLScript
A simple command line script written in Swift to pull in multiple cryptocurrency prices from Coinmarketcap API.

![](https://raw.githubusercontent.com/mrdavey/CryptoCLScript/master/sample.gif)

Historic and recent prices are recorded in a text file located in your `Documents` folder.

To run script, go to directory in terminal and execute `./main.swift`

## To add other cryptocurrencies
You can easily add the cryptocurrencies you want to track by adding them in `main.swift` as an enum, then making the network call.

Note: You'll need to use the ID that Coinmarketcap uses. E.g. In `https://coinmarketcap.com/assets/gnosis-gno/`, the part after `assets` would be GNO's ID.


## Pro-tip
To run it anywhere in Terminal with a command like `crypto`:
```
swiftc main.swift -o crypto
sudo cp crypto /usr/local/bin
```
## To Do
 * Ability to show other currencies (besides USD)
