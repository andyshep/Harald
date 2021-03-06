//
//  ServiceNode.swift
//  Harald
//
//  Created by Andrew Shepard on 4/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine
import CoreBluetooth

@objc open class DataNode: NSObject { }

@objc final class ServiceNode: DataNode {
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

@objc final class CharacteristicNode: DataNode {
    @objc let name: String
    @objc var value: String = ""
    
    let characteristic: CBCharacteristic
    
    private var cancellables = Set<AnyCancellable>()
    
    init(characteristic: CBCharacteristic) {
        self.characteristic = characteristic
        self.name = characteristic.uuid.description
        
        super.init()
        
        bind(to: characteristic)
    }
    
    deinit {
        cancellables.cancel()
    }
    
    @objc var isLeaf: Bool {
        return true
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let node = object as? CharacteristicNode else { return false }
        return node.characteristic.isEqual(to: characteristic)
    }
    
    private func bind(to characteristic: CBCharacteristic) {
        guard characteristic.properties.contains(.read) else { return }
        guard !characteristic.properties.contains(.notifyEncryptionRequired) else { return }
        
        characteristic
            .valuePublisher
            .compactMap { result -> String in
                switch result {
                case .success(let data):
                    guard let data = data else { return "Empty" }
                    guard let string = String(data: data, encoding: .utf8) else {
                        return data.hexEncodedString(options: [.upperCase])
                    }
                    return string
                case .failure(let error):
                    return error.localizedDescription
                }
            }
            .sink { [weak self] (value) in
                self?.willChangeValue(for: \.value)
                self?.value = value
                self?.didChangeValue(for: \.value)
            }
            .store(in: &cancellables)
    }
}

@objc final class PacketNode: DataNode {
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
