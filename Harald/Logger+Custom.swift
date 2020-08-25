//
//  Logger.swift
//  Harald
//
//  Created by Andrew Shepard on 8/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs messages related to CoreBluetooth
    static let bluetooth = OSLog(subsystem: subsystem, category: "CoreBluetooth")
}
