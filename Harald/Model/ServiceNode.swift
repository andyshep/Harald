//
//  ServiceNode.swift
//  Harald
//
//  Created by Andrew Shepard on 4/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth

@objc class DataNode: NSObject { }

@objc class ServiceNode: DataNode {
    @objc let name: String
    @objc let value: String = ""
    @objc var characteristics: [CharacteristicNode]
    
    let service: CBService
    
    init(service: CBService, characteristics: [CharacteristicNode] = []) {
        self.service = service
        self.name = service.uuid.description
        self.characteristics = characteristics
        super.init()
    }
    
    @objc var isLeaf: Bool {
        return false
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let node = object as? ServiceNode else { return false }
        return node.service.isEqual(to: self.service)
    }
}

@objc class CharacteristicNode: DataNode {
    @objc let name: String
    private var _value: String? = ""
    
    @objc var value: String {
        return _value ?? ""
    }
    
    @objc let characteristic: CBCharacteristic
    
    init(characteristic: CBCharacteristic) {
        self.characteristic = characteristic
        self.name = characteristic.uuid.description
        super.init()
        
        bind(to: characteristic)
    }
    
    @objc var isLeaf: Bool {
        return true
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let node = object as? CharacteristicNode else { return false }
        return node.characteristic.isEqual(to: self.characteristic)
    }
    
    private func bind(to characteristic: CBCharacteristic) {        
//        characteristic
//            .rx
//            .value
//            .asDriver(onErrorJustReturn: nil)
//            .map { (data) -> String? in
//                guard let data = data else { return nil }
//                guard let string = String(data: data, encoding: .utf8) else {
//                    return data.hexEncodedString().uppercased()
//                }
//
//                return string
//            }
//            .drive(onNext: { [weak self] (value) in
//                self?.willChangeValue(for: \.value)
//                self?._value = value ?? "Cannot Read Value"
//                self?.didChangeValue(for: \.value)
//            })
//            .disposed(by: bag)
    }
}

@objc class PacketNode: DataNode {
    @objc let name: String
    @objc let value: String
    @objc let children: [PacketNode]
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
        self.children = []
        super.init()
    }
    
    @objc var isLeaf: Bool {
        return children.count == 0
    }
}
