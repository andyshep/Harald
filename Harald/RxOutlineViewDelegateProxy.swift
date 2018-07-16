//
//  RxOutlineViewDelegateProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 4/29/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import AppKit
import RxSwift
import RxCocoa

extension NSOutlineView: HasDelegate {
    public typealias Delegate = NSOutlineViewDelegate
}

public final class RxOutlineViewDelegateProxy
    : DelegateProxy<NSOutlineView, NSOutlineViewDelegate>
    , DelegateProxyType
    , NSOutlineViewDelegate {
    
    // MARK: Lifecycle
    
    private init(parent: NSOutlineView) {
        super.init(parentObject: parent, delegateProxy: RxOutlineViewDelegateProxy.self)
        parent.delegate = self
    }
    
    // MARK: <DelegateProxyType>
    
    public static func registerKnownImplementations() {
        self.register { (parent) -> RxOutlineViewDelegateProxy in
            return RxOutlineViewDelegateProxy(parent: parent)
        }
    }
}
