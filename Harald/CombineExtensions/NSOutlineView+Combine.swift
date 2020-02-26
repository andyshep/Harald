//
//  NSOutlineView+Combine.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Cocoa
import Combine

extension NSOutlineView {
    
    /// Publisher that emits with an index associated with an `IndexPath`
    typealias IndexPublisher = AnyPublisher<Int, Never>
    
    /// Emits with the index of an item that will expand
    var itemWillExpandPublisher: IndexPublisher {
        return proxy.itemWillExpandPublisher
    }
    
    /// Emits with the index of an item that did expand
    var itemDidExpandPublisher: IndexPublisher {
        return proxy.itemDidExpandPublisher
    }
    
    private var proxy: OutlineViewProxy {
        get {
            guard let value = objc_getAssociatedObject(self, &_outlineViewProxyKey) as? OutlineViewProxy else {
                let proxy = OutlineViewProxy(outlineView: self)
                objc_setAssociatedObject(self, &_outlineViewProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return proxy
            }
            return value
        }
    }
}

private var _outlineViewProxyKey: UInt8 = 0
private class OutlineViewProxy: NSObject {
    
    var itemWillExpandPublisher: AnyPublisher<Int, Never> {
        return _itemWillExpandPublisher.eraseToAnyPublisher()
    }
    private let _itemWillExpandPublisher = PassthroughSubject<Int, Never>()
    
    var itemDidExpandPublisher: AnyPublisher<Int, Never> {
        return _itemDidExpandPublisher.eraseToAnyPublisher()
    }
    private let _itemDidExpandPublisher = PassthroughSubject<Int, Never>()

    private let outlineView: NSOutlineView

    init(outlineView: NSOutlineView) {
        self.outlineView = outlineView
        super.init()
        
        outlineView.delegate = self
    }
}

// MARK: <NSOutlineViewDelegate>

extension OutlineViewProxy: NSOutlineViewDelegate {
    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let object = notification.userInfo?["NSObject"] else { return }
        
        let index = self.outlineView.row(forItem: object)
        _itemWillExpandPublisher.send(index)
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let object = notification.userInfo?["NSObject"] else { return }
        
        let index = self.outlineView.row(forItem: object)
        _itemDidExpandPublisher.send(index)
    }
}
