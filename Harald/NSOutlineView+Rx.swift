//
//  NSOutlineView+Rx.swift
//  Harald
//
//  Created by Andrew Shepard on 4/29/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import AppKit
import RxSwift
import RxCocoa

extension Reactive where Base: NSOutlineView {
    var itemAtIndexWillExpandEvent: Observable<Int> {
        let selector = #selector(
            NSOutlineViewDelegate.outlineViewItemWillExpand(_:)
        )

        return RxOutlineViewDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { (params) -> Int in
                let notification = params[0] as! NSNotification
                let object = notification.userInfo!["NSObject"]
                let row = self.base.row(forItem: object)
                return row
            }
    }
    
    var itemAtIndexDidExpandEvent: Observable<Int> {
        let selector = #selector(
            NSOutlineViewDelegate.outlineViewItemDidExpand(_:)
        )
        
        return RxOutlineViewDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { (params) -> Int in
                let notification = params[0] as! NSNotification
                let object = notification.userInfo!["NSObject"]
                let row = self.base.row(forItem: object)
                return row
        }
    }
}
