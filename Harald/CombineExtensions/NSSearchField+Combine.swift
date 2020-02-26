//
//  NSSearchField+Combine.swift
//  Harald
//
//  Created by Andrew Shepard on 2/25/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Cocoa
import Combine

extension NSSearchField {
    
    typealias ValuePublisher = AnyPublisher<String, Never>
    
    var stringValuePublisher: ValuePublisher {
        return proxy.stringValuePublisher
    }
    
    private var proxy: SearchFieldProxy {
        get {
            guard let value = objc_getAssociatedObject(self, &_searchFieldProxyKey) as? SearchFieldProxy else {
                let proxy = SearchFieldProxy(searchField: self)
                objc_setAssociatedObject(self, &_searchFieldProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return proxy
            }
            return value
        }
    }
}

private var _searchFieldProxyKey: UInt8 = 0
private class SearchFieldProxy: NSObject {
    
    var stringValuePublisher: AnyPublisher<String, Never> {
        return _stringValuePublisher.eraseToAnyPublisher()
    }
    private let _stringValuePublisher = PassthroughSubject<String, Never>()

    private let searchField: NSSearchField

    init(searchField: NSSearchField) {
        self.searchField = searchField
        super.init()
        
        searchField.delegate = self
    }
    
    deinit {
        searchField.delegate = nil
    }
}

// MARK: <NSSearchFieldDelegate>

extension SearchFieldProxy: NSSearchFieldDelegate { }

// MARK: <NSControlTextEditingDelegate>

extension SearchFieldProxy: NSControlTextEditingDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard
            let field = notification.object as? NSSearchField,
            searchField == field
        else { return }
        
        let value = searchField.stringValue
        _stringValuePublisher.send(value)
    }
}
