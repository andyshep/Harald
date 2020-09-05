//
//  ServicesViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 4/14/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import AppKit
import CoreBluetooth
import Combine

final class ServicesViewController: NSViewController {
    
    private enum GeneralError: Error {
        case peripheralProxyIsNil
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var peripheralCancellables = Set<AnyCancellable>()
    
    // MARK: Inputs
    
    public let reloadEvent = PassthroughSubject<Void, Never>()
    public let exportEvent = PassthroughSubject<Void, Never>()
    
    // MARK: Public
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    public var manager: CBCentralManager?
    public var peripheral: CBPeripheral?
    
    lazy var servicesController: NSTreeController = {
        let controller = NSTreeController()
        
        controller.bind(NSBindingName.content, to: self, withKeyPath: "services")
        controller.childrenKeyPath = "characteristics"
        controller.leafKeyPath = "isLeaf"
        
        return controller
    }()
    
    @objc var services: [DataNode] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outlineView.bind(.content, to: servicesController, withKeyPath: "arrangedObjects")
        outlineView.bind(.selectionIndexPaths, to: servicesController, withKeyPath: "selectionIndexPaths")
        
        outlineView.itemWillExpandPublisher
            .sink { [weak self] _ in
                self?.willChangeValue(for: \.services)
            }
            .store(in: &cancellables)
        
        outlineView.itemDidExpandPublisher
            .sink { [weak self] _ in
                self?.didChangeValue(for: \.services)
            }
            .store(in: &cancellables)
        
        reloadEvent
            .sink { [weak self] _ in
                self?.representedObject = nil
            }
            .store(in: &cancellables)
        
        exportEvent
            .sink { _ in
                // TODO: implement
            }
            .store(in: &cancellables)
    }
    
    override var representedObject: Any? {
        didSet {
            // make sure we're given a CBPeripheral
            guard let peripherial = representedObject as? CBPeripheral else { return }
            
            self.willChangeValue(for: \.services)
            self.services = []
            self.didChangeValue(for: \.services)
            
            // bind to peripherial upon exit
            defer {
                peripheralCancellables.cancel()
                bind(to: peripherial)
            }
            
            // cancel
            guard let oldPeripheral = oldValue as? CBPeripheral else { return }
            manager?.cancelPeripheralConnection(oldPeripheral)
        }
    }
}

private extension ServicesViewController {
    private func reloadServiceNodes(using services: [CBService]) {
        self.willChangeValue(for: \.services)
        self.services = services.compactMap { ServiceNode(service: $0) }
        self.didChangeValue(for: \.services)
    }
    
    private func updateCharacteristicNodes(_ characteristics: [CharacteristicNode], for service: CBService) {
        // find service to update, make sure characteristics don't match
        let node = services.first { ($0 as? ServiceNode)?.service == service }
        guard let serviceNode = node as? ServiceNode else { return }
        guard serviceNode.characteristics != characteristics else { return }
        
        serviceNode.willChangeValue(for: \ServiceNode.characteristics)
        serviceNode.characteristics = characteristics
        serviceNode.didChangeValue(for: \ServiceNode.characteristics)
    }
    
    private func bind(to peripheral: CBPeripheral) {
        manager?.connect(to: peripheral)
            // once connected, ask the peripheral to discover *and* publish services
            .flatMap { peripheral -> AnyPublisher<[CBService], Error> in
                return peripheral.discoveredServicesPublisher
            }
            .prefix(1)
            // set the initial response containing services without charactertics
            .do(onNext: { [weak self] (services) in
                self?.reloadServiceNodes(using: services)
            })
            // discover characteristics for each service by returning
            // an observable tuple stream of services and characteristics
            .flatMapLatest { (services) -> AnyPublisher<(CBService, [CBCharacteristic]), Error> in
                let publishers = services.compactMap { $0.discoveredCharacteristics }
                return Publishers.MergeMany(publishers)
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { _ in () },
                receiveValue: { [weak self] (service, characteristics) in
                    let nodes = characteristics
                        .compactMap { CharacteristicNode(characteristic: $0) }
                    
                    // update the service nodes with the characteristics (after they are discovered)
                    self?.updateCharacteristicNodes(nodes, for: service)
                    
                    self?.outlineView.expandItem(nil, expandChildren: true)
    
                    // initiate a call to read each charactertistics value and descriptors
                    // these will come back later through another Rx pipeline
                    nodes.forEach { node in
                        peripheral.discoverDescriptors(for: node.characteristic)
                        peripheral.readValue(for: node.characteristic)
                    }
                }
            )
            .store(in: &cancellables)
    }
}
