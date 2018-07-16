//
//  PeripheralsViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import RxSwift
import RxCocoa

class PeripheralsViewController: NSViewController {
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var statusTextField: NSTextField!
    
    @objc private var peripherals: [CBPeripheral] = []
    
    private let bag = DisposeBag()
    
    public var manager: CBCentralManager? {
        didSet {
            guard let manager = manager else { return }
            bind(to: manager)
        }
    }
    
    lazy var peripheralsController: NSArrayController = {
        let controller = NSArrayController()
        controller.bind(.contentArray, to: self, withKeyPath: "peripherals")
        
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.bind(.content, to: peripheralsController, withKeyPath: "arrangedObjects")
        tableView.bind(.selectionIndexes, to: peripheralsController, withKeyPath: "selectionIndexes")
        
        bind(to: peripheralsController)
    }
}

extension PeripheralsViewController {
    func bind(to manager: CBCentralManager) {
        manager.rx.discoveredPeripheral
            .subscribe(onNext: { [weak self] (peripheral) in
                guard let this = self else { return }
                if !this.peripherals.contains(peripheral) {
                    this.willChangeValue(for: \.peripherals)
                    this.peripherals.append(peripheral)
                    this.didChangeValue(for: \.peripherals)
                }
            })
            .disposed(by: bag)
        
        manager.rx.state
            .startWith(CBManagerState.unknown)
            .filter { $0 == .poweredOn }
            .take(1)
            .subscribe(onNext: { [weak self] (state) in
                self?.manager?.scanForPeripherals(withServices: nil)
            })
            .disposed(by: bag)
    }
    
    func bind(to arrayController: NSArrayController) {
        arrayController
            .rx
            .observeWeakly([AnyObject].self, "arrangedObjects", options: [.initial, .new])
            .map { [weak self] _ -> Int in
                guard let controller = self?.peripheralsController else { return 0 }
                guard let objects = controller.arrangedObjects as? [AnyObject] else { return 0 }
                return objects.count
            }
            .map { count -> String in
                switch count {
                case 0:
                    return "No peripherals discovered"
                case 1:
                    return "1 peripheral discovered"
                default:
                    return "\(count) peripherals discovered"
                }
            }
            .asDriver(onErrorJustReturn: "No peripherals discovered")
            .drive(onNext: { [weak self] (result) in
                self?.statusTextField.stringValue = result
            })
            .disposed(by: bag)
    }
}
