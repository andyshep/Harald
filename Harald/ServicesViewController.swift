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

class ServicesViewController: NSViewController {
    
    private enum GeneralError: Error {
        case peripheralProxyIsNil
    }
    
    private var cancelables: [AnyCancellable] = []
    private var peripheralCancelables: [AnyCancellable] = []
    
    // MARK: Inputs
    
    public let reloadEvent = PassthroughSubject<Void, Never>()
    public let exportEvent = PassthroughSubject<Void, Never>()
    
    // MARK: Public
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    lazy var outlineViewProxy = OutlineViewProxy(outlineView: outlineView)
    
    public var proxy: CentralManagerProxy?
    private var peripheralProxy: PeripheralProxy?
    
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
        
        outlineViewProxy.itemWillExpandPublisher
            .sink { [weak self] _ in
                self?.willChangeValue(for: \.services)
            }
            .store(in: &cancelables)
        
        outlineViewProxy.itemDidExpandPublisher
            .sink { [weak self] _ in
                self?.didChangeValue(for: \.services)
            }
            .store(in: &cancelables)
        
        reloadEvent
            .sink { [weak self] _ in
                self?.representedObject = nil
            }
            .store(in: &cancelables)
        
        exportEvent
            .sink { _ in
                // TODO: implement
            }
            .store(in: &cancelables)
    }
    
    override var representedObject: Any? {
        didSet {
            self.willChangeValue(for: \.services)
            self.services = []
            self.didChangeValue(for: \.services)
            
            guard let peripherial = representedObject as? CBPeripheral else {
                return
            }
            
            if let oldPeripheral = oldValue as? CBPeripheral {
                // close any previous connections
                proxy?.manager.cancelPeripheralConnection(oldPeripheral)
                
                if peripherial != oldPeripheral {
                    // update
                    bind(to: peripherial)
                } else {
                    print("not updating")
                }
            } else {
                // update
                bind(to: peripherial)
            }
        }
    }
}

private extension ServicesViewController {
    private func reloadServiceNodes(using services: [CBService]) {
        let nodes = services.compactMap { ServiceNode(service: $0) }
        
        self.willChangeValue(for: \.services)
        self.services = nodes
        self.didChangeValue(for: \.services)
    }
    
    private func updateCharacteristics(_ characteristics: [CBCharacteristic], for service: CBService) {
        // create the characteristic nodes
        let characteristics = characteristics.compactMap { characteristic -> CharacteristicNode in
            let node = CharacteristicNode(characteristic: characteristic)
            return node
        }
        
        let node = services.first { (node) -> Bool in
            guard let current = node as? ServiceNode else { return false }
            return current.service == service
        }
        
        guard let serviceNode = node as? ServiceNode else { return }
        
        serviceNode.willChangeValue(for: \ServiceNode.characteristics)
        serviceNode.characteristics = characteristics
        serviceNode.didChangeValue(for: \ServiceNode.characteristics)
    }
    
    private func bind(to peripheral: CBPeripheral) {
        peripheralCancelables.forEach { $0.cancel() }
        peripheralCancelables = []
        
        self.peripheralProxy = PeripheralProxy(peripheral: peripheral)
        
        proxy?.connect(to: peripheral)
            .flatMap { [weak self] peripheral -> AnyPublisher<[CBService], Error> in
                guard
                    let peripheralProxy = self?.peripheralProxy
                else {
                    return Fail<[CBService], Error>(error: GeneralError.peripheralProxyIsNil)
                        .eraseToAnyPublisher()
                }
                
                peripheral.discoverServices(nil)
                return peripheralProxy.discoveredServicesPublisher
            }
            // set the initial response containing services without charactertics
            .do(onNext: { [weak self] (services) in
                self?.reloadServiceNodes(using: services)
            })
            // discover characteristics for each service by returning
            // an observable tuple stream of services and characteristics
//            .flatMap { (services) -> AnyPublisher<(CBService, [CBCharacteristic]), Error> in
//
//
//                let characteristics = services.compactMap { $0.rx.discoveredCharacteristics }
//                return Observable.merge(characteristics)
//            }
            .sink(receiveCompletion: { _ in
                //
            }, receiveValue: { (services) in
                print(services)
            })
            .store(in: &cancelables)
        
//        manager?.rx.connect(to: peripheral)
//            .asObservable()
//            .flatMapLatest { $0.rx.discoveredServices }
//            // set the initial response containing services without charactertics
//            .map { [weak self] services -> [CBService] in
//                self?.reloadServiceNodes(using: services)
//                return services
//            }
//            // discover characteristics for each service by returning
//            // an observable tuple stream of services and characteristics
//            .flatMap { (services) -> Observable<(CBService, [CBCharacteristic])> in
//                let characteristics = services.compactMap { $0.rx.discoveredCharacteristics }
//                return Observable.merge(characteristics)
//            }
//            // update the service nodes with the characterics once discovered
//            .map { [weak self] (service, characterics) in
//                guard let this = self else { return }
//
//                // initiate a call to read each charactertistics value
//                // this will come back later through another Rx pipeline
//                characterics.forEach { peripheral.readValue(for: $0) }
//
//                this.updateCharacteristics(characterics, for: service)
//                this.outlineView.expandItem(nil, expandChildren: true)
//            }
//            .subscribe()
//            .disposed(by: peripheralsBag)
    }
}
