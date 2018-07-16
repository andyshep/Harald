//
//  PeripheralsDataSource.swift
//  Harald
//
//  Created by Andrew Shepard on 2/25/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxCocoa

class PeripheralsDataSource {
    let service = BluetoothService()
    
    lazy var peripherals: Variable<[CBPeripheral]> = {
        
        service.peripherials
    }()
}
