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
    
    // MARK: Inputs
    
    public let reloadEvent = PublishSubject<Void>()
    public let exportEvent = PublishSubject<Void>()
    
    // MARK: Public
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    public var manager: CBCentralManager?
    
    private let bag = DisposeBag()
    private var peripheralsBag = DisposeBag()
    
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
        
        reloadEvent
            .subscribe { [weak self] _ in
                self?.representedObject = nil
            }
            .disposed(by: bag)
        
        exportEvent
            .subscribe { _ in
                print("export: \(self.services)")
            }
            .disposed(by: bag)
    }
    
    override var representedObject: Any? {
        didSet {
            self.willChangeValue(for: \.services)
            self.services = []
            self.didChangeValue(for: \.services)
            
            guard let peripherial = representedObject as? CBPeripheral else {
                peripheralsBag = DisposeBag()
                return
            }
            
            if let oldPeripheral = oldValue as? CBPeripheral {
                if peripherial != oldPeripheral {
                    // update
                    peripheralsBag = DisposeBag()
                    bind(to: peripherial)
                } else {
                    print("not updating")
                }
            } else {
                // update
                peripheralsBag = DisposeBag()
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
                guard let this = self else { return }
                
                // initiate a call to read each charactertistics value
                // this will come back later through another Rx pipeline
                characterics.forEach { peripheral.readValue(for: $0) }
                
                this.updateCharacteristics(characterics, for: service)
                this.outlineView.expandItem(nil, expandChildren: true)
            }
            .subscribe()
            .disposed(by: peripheralsBag)
    }
}
