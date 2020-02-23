//
//  OutlineViewProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Cocoa
import Combine

public final class OutlineViewProxy: NSObject {
    
    /// Emits with the index of an item that will expand
    public var itemWillExpandPublisher: AnyPublisher<Int, Never> {
        return _itemWillExpandPublisher.eraseToAnyPublisher()
    }
    private let _itemWillExpandPublisher = PassthroughSubject<Int, Never>()
    
    /// Emits with the index of an item that did expand
    public var itemDidExpandPublisher: AnyPublisher<Int, Never> {
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
    public func outlineViewItemWillExpand(_ notification: Notification) {
        guard let object = notification.userInfo?["NSObject"] else { return }
        
        let index = self.outlineView.row(forItem: object)
        _itemWillExpandPublisher.send(index)
    }
    
    public func outlineViewItemDidExpand(_ notification: Notification) {
        guard let object = notification.userInfo?["NSObject"] else { return }
        
        let index = self.outlineView.row(forItem: object)
        _itemDidExpandPublisher.send(index)
    }
}
