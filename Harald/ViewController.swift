//
//  ViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import RxSwift
import RxCocoa

extension ObservableType where E: Sequence, E.Iterator.Element: Equatable {
    func distinctUntilChanged() -> Observable<E> {
        return distinctUntilChanged { (lhs, rhs) -> Bool in
            return Array(lhs) == Array(rhs)
        }
    }
}

class ViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    
    private let bag = DisposeBag()
    private let service = BluetoothService()
    
    private var objects: [CBPeripheral] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        _ = service.centralManager.state

        service.peripherials
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] (periperhals) in
                self.objects = periperhals
                self.tableView.reloadData()
            })
            .disposed(by: bag)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return objects.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: "NameCell")
        if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            let object = objects[row]
            
            cell.textField?.stringValue = object.name ?? "No Name"
            return cell
        }
        
        return nil
    }
}
