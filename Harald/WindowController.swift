//
//  WindowController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/25/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import AppKit
import CoreBluetooth
import RxSwift

class WindowController: NSWindowController {
    
    private let centralManager = CBCentralManager()
    private let bag = DisposeBag()
    
    lazy private var peripheralsViewController: PeripheralsViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.children[0] as? PeripheralsViewController else { fatalError() }
        return viewController
    }()
    
    lazy private var servicesViewController: ServicesViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.children[1] as? ServicesViewController else { fatalError() }
        return viewController
    }()
    
    lazy private var detailViewController: DetailViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.children[2] as? DetailViewController else { fatalError() }
        return viewController
    }()
    
    lazy private var peripheralsArrayController: NSArrayController = {
        let controller = self.peripheralsViewController.peripheralsController
        return controller
    }()
    
    lazy private var servicesTreeController: NSTreeController = {
        let controller = self.servicesViewController.servicesController
        return controller
    }()
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titleVisibility = .hidden
        
        peripheralsViewController.manager = centralManager
        servicesViewController.manager = centralManager
        
        peripheralsArrayController
            .rx
            .observeWeakly(Int.self, "selectionIndex", options: [.new])
            .map { [weak self] _ -> CBPeripheral? in
                let selected = self?.peripheralsArrayController.selectedObjects
                return selected?.first as? CBPeripheral
            }
            .asDriver(onErrorJustReturn: nil)
            .filter { $0 != nil }
            .distinctUntilChanged()
            .drive(onNext: { [weak self] (peripheral) in
                self?.servicesViewController.representedObject = peripheral
            })
            .disposed(by: bag)
        
        servicesTreeController
            .rx
            .observeWeakly(NSIndexPath.self, "selectionIndexPaths", options: [.new])
            .map { [weak self] _ -> CBCharacteristic? in
                let selected = self?.servicesTreeController.selectedObjects
                guard let node = selected?.first as? CharacteristicNode else { return nil }
                return node.characteristic
            }
            .asDriver(onErrorJustReturn: nil)
            .filter { $0 != nil }
            .distinctUntilChanged()
            .drive(onNext: { [weak self] (characteristic) in
                self?.detailViewController.representedObject = characteristic
            })
            .disposed(by: bag)
    }
}
