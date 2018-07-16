//
//  Data+HexEncoding.swift
//  Harald
//
//  Created by Andrew Shepard on 7/15/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation

// https://stackoverflow.com/a/40089462

extension Data {
    struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
