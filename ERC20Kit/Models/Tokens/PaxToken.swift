//
//  PaxToken.swift
//  ERC20Kit
//
//  Created by Jack on 15/04/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt
import PlatformKit
import EthereumKit

public struct PaxToken: ERC20Token {
    //swiftlint:disable:next force_try
    public static var smallestSpendableValue: ERC20TokenValue<PaxToken> = try! ERC20TokenValue<PaxToken>(
        crypto: CryptoValue.createFromMajorValue(string: "0.01", assetType: .pax, locale: Locale(identifier: "en_US"))!
    )
    
    public static let assetType: CryptoCurrency = .pax
    public static let contractAddress: EthereumContractAddress = "0x8E870D67F660D95d5be530380D0eC0bd388289E1"
    
    public static func cryptoValueFrom(majorValue: String) -> ERC20TokenValue<PaxToken>? {
        guard let cryptoValue = CryptoValue.paxFromMajor(string: majorValue) else {
            return nil
        }
        return try? ERC20TokenValue<PaxToken>(crypto: cryptoValue)
    }
    
    public static func cryptoValueFrom(minorValue: String) -> ERC20TokenValue<PaxToken>? {
        guard let minorBigInt = BigInt(minorValue) else {
            return nil
        }
        return try? ERC20TokenValue<PaxToken>(crypto: CryptoValue.createFromMinorValue(minorBigInt, assetType: assetType))
    }
    
    public static func cryptoValueFrom(minorValue: BigInt) -> ERC20TokenValue<PaxToken>? {
        return try? ERC20TokenValue<PaxToken>(crypto: CryptoValue.createFromMinorValue(minorValue, assetType: assetType))
    }
}
