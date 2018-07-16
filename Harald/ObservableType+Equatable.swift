//
//  ObservableType+Equatable.swift
//  Harald
//
//  Created by Andrew Shepard on 4/15/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType where E: Sequence, E.Iterator.Element: Equatable {
    func distinctUntilChanged() -> Observable<E> {
        return distinctUntilChanged { (lhs, rhs) -> Bool in
            return Array(lhs) == Array(rhs)
        }
    }
}

extension ObservableType where E: Equatable {
    public func distinctUntilChanged() -> Observable<E> {
        return self.distinctUntilChanged({ $0 }, comparer: { ($0 == $1) })
    }
}
