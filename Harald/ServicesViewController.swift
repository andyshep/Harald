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
import RxSwift
import RxCocoa

class ServicesViewController: NSViewController {
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    public var manager: CBCentralManager?
    
    private var bag = DisposeBag()
    
    lazy var servicesController: NSTreeController = {
        let controller = NSTreeController()
        
        controller.bind(NSBindingName.content, to: self, withKeyPath: "services")
        controller.childrenKeyPath = "characteristics"
        controller.leafKeyPath = "isLeaf"
        
        return controller
    }()
    
    @objc var services: [DataNode] = []
    
//    @objc var services: [DataNode] {
//        return [
//            ServiceNode(name: "Service Name 1"),
//            CharacteristicNode(name: "characteristic uno"),
//            CharacteristicNode(name: "characteristic dos"),
//            ServiceNode(name: "Service Name 2"),
//            CharacteristicNode(name: "characteristic uno"),
//            CharacteristicNode(name: "characteristic dos"),
//            CharacteristicNode(name: "characteristic trés")
//        ]
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outlineView.bind(.content, to: servicesController, withKeyPath: "arrangedObjects")
        outlineView.bind(.selectionIndexPaths, to: servicesController, withKeyPath: "selectionIndexPaths")
        
        outlineView.rx.itemAtIndexWillExpandEvent
            .subscribe(onNext: { [weak self] _ in
                self?.willChangeValue(for: \.services)
            })
            .disposed(by: bag)
        
        outlineView.rx.itemAtIndexDidExpandEvent
            .subscribe(onNext: { [weak self] index in
                self?.didChangeValue(for: \.services)
            })
            .disposed(by: bag)
    }
    
    override var representedObject: Any? {
        didSet {
            guard let peripherial = representedObject as? CBPeripheral else { return }
            
            self.willChangeValue(for: \.services)
            self.services = []
            self.didChangeValue(for: \.services)
            
            if let oldPeripheral = oldValue as? CBPeripheral {
                if peripherial != oldPeripheral {
                    // update
                    bag = DisposeBag()
                    bind(to: peripherial)
                } else {
                    print("not updating")
                }
            } else {
                // update
                bag = DisposeBag()
                bind(to: peripherial)
            }
        }
    }
}

extension ServicesViewController {
    private func reloadServiceNodes(using services: [CBService]) {
        let nodes = services.compactMap { ServiceNode(service: $0) }
        
        self.willChangeValue(for: \.services)
        self.services = nodes
        self.didChangeValue(for: \.services)
    }
    
    private func updateExistingServiceNodes(using serviceNode: ServiceNode) {
        let index = self.services.firstIndex(where: { (node) -> Bool in
            guard let currentNode = node as? ServiceNode else { return false }
            return currentNode.name == serviceNode.name
        })
        
        guard let _ = index else { return }
        
        self.willChangeValue(for: \.services)
        self.services[index!] = serviceNode
        self.didChangeValue(for: \.services)
    }
    
    private func bind(to peripheral: CBPeripheral) {
        manager?.rx.connect(to: peripheral)
            .asObservable()
            .flatMapLatest { $0.rx.discoveredServices }
            // set the initial response containing services without charactertics
            .map { [weak self] services -> [CBService] in
                self?.reloadServiceNodes(using: services)
                return services
            }
            // discover characteristics for each service by returning
            // an observable tuple stream of services and characteristics
            .flatMap { (services) -> Observable<(CBService, [CBCharacteristic])> in
                let characteristics = services.compactMap { $0.rx.discoveredCharacteristics }
                return Observable.merge(characteristics)
            }
            // update the service nodes with the characterics once discovered
            .map { [weak self] (service, characterics) in
                characterics.forEach { peripheral.readValue(for: $0) }
                let serviceNode = ServiceNode(service: service)
                serviceNode.characteristics = characterics.compactMap { characteristic -> CharacteristicNode in
                    let node = CharacteristicNode(characteristic: characteristic)
                    return node
                }
                self?.updateExistingServiceNodes(using: serviceNode)
                
                self?.outlineView.expandItem(nil, expandChildren: true)
            }
            .subscribe()
            .disposed(by: bag)
    }
}
