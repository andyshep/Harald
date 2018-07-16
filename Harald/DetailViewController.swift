//
//  DetailViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 7/14/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import RxSwift

class DetailViewController: NSViewController {
    
    @IBOutlet private weak var textField: NSTextField!
    
    private let bag = DisposeBag()
    
    override var representedObject: Any? {
        didSet {
//            guard let characteristic = representedObject as? CBCharacteristic else { return }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
}
