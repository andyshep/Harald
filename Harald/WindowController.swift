//
//  WindowController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/25/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import Cocoa
import CoreBluetooth
import Combine

class WindowController: NSWindowController {
    
    private var cancellables: [AnyCancellable] = []
    
    private let centralManager = CBCentralManager()
    
    @IBOutlet private weak var reloadButton: NSButton!
    @IBOutlet private weak var exportButton: NSButton!
    
    lazy private var peripheralsViewController: PeripheralsViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.splitViewItems[0].viewController as? PeripheralsViewController else { fatalError() }
        return viewController
    }()
    
    lazy private var servicesViewController: ServicesViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.splitViewItems[1].viewController as? ServicesViewController else { fatalError() }
        return viewController
    }()
    
    lazy private var detailViewController: DetailViewController = {
        guard let splitViewController = contentViewController as? NSSplitViewController else { fatalError() }
        guard let viewController = splitViewController.splitViewItems[2].viewController as? DetailViewController else { fatalError() }
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
            .selectionIndexPublisher
            .compactMap { [weak self] _ -> DiscoveredPeripheral? in
                let selected = self?.peripheralsArrayController.selectedObjects
                return selected?.first as? DiscoveredPeripheral
            }
            .removeDuplicates()
            .sink { [weak self] discovered in
                self?.servicesViewController.representedObject = discovered.peripheral
                self?.detailViewController.representedObject = discovered.packet
            }
            .store(in: &cancellables)
        
        servicesTreeController
            .selectionIndexPathsPublisher
            .compactMap { [weak self] _ -> CBCharacteristic? in
                let selected = self?.servicesTreeController.selectedObjects
                guard let node = selected?.first as? CharacteristicNode else { return nil }
                return node.characteristic
            }
            .removeDuplicates()
            .sink { [weak self] (characteristic) in
                self?.detailViewController.representedObject = characteristic
            }
            .store(in: &cancellables)
        
        reloadButton
            .publisher
            .sink { [weak self] _ in
                self?.peripheralsViewController.reloadEvent.send(())
                self?.servicesViewController.representedObject = nil
                self?.detailViewController.representedObject = [:]
            }
            .store(in: &cancellables)
        
        exportButton
            .publisher
            .sink { [weak self] _ in
                self?.servicesViewController.exportEvent.send(())
            }
            .store(in: &cancellables)
    }
}
