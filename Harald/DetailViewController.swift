//
//  DetailViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 7/14/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import Combine

class DetailViewController: NSViewController {
    
    private var cancellables = Set<AnyCancellable>()
    
    @IBOutlet private weak var outlineView: NSOutlineView!
    
    @objc var packets: [PacketNode] = []
    
    lazy var packetsController: NSTreeController = {
        let controller = NSTreeController()
        
        controller.bind(NSBindingName.content, to: self, withKeyPath: "packets")
        controller.childrenKeyPath = "children"
        controller.leafKeyPath = "isLeaf"
        
        return controller
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outlineView.bind(.content, to: packetsController, withKeyPath: "arrangedObjects")
        
        self.representedObjectPublisher
            .compactMap { object -> [PacketNode]? in
                guard let packet = object as? [String: Any] else { return nil }
                return packet
                    .enumerated()
                    .map { Advertisement(element: $0.1) }
                    .map { PacketNode(name: $0.name, value: $0.value) }
            }
            .sink { [weak self] (packets) in
                self?.willChangeValue(for: \.packets)
                self?.packets = packets
                self?.didChangeValue(for: \.packets)
            }
            .store(in: &cancellables)
    }
}

@objc class Advertisement: NSObject {
    
    typealias Element = (key: String, value: Any)
    
    @objc let name: String
    @objc let value: String
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
        super.init()
    }
    
    init(element: Element) {
        self.name = element.key
        self.value = stringValue(from: element.value)
        super.init()
    }
}

private func stringValue(from obj: Any) -> String {
    if let data = obj as? Data {
        return data.hexEncodedString()
    } else if let string = obj as? String {
        return string
    } else if let number = obj as? Int {
        return "\(number)"
    } else if let uuids = obj as? [CBUUID] {
        return "\(uuids.count) UUIDs"
    } else if let attributes = obj as? [String: Any] {
        return "\(attributes.count) Attributes"
    } else {
        return "Unknown Format"
    }
}
