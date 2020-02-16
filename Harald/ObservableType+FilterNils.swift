//
//  ObservableType+FilterNils.swift
//  Harald
//
//  Created by Andrew Shepard on 7/14/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

// https://gist.github.com/gravicle/8fd14b940e97e6d4bc7ecfec3703fd2e

import Foundation
import RxSwift

public protocol OptionalType {
    associatedtype Wrapped
    var value: Wrapped? { get }
}

extension Optional: OptionalType {
    public var value: Wrapped? {
        return self
    }
}

public extension ObservableType where Element: OptionalType {
    
    /// Filter nil values from the Observable stream
    ///
    /// - Returns: A filtered stream with nil values removed
    func filterNils() -> Observable<Element.Wrapped> {
        return self.flatMap { element -> Observable<Element.Wrapped> in
            guard let value = element.value else {
                return Observable<Element.Wrapped>.empty()
            }
            return Observable<Element.Wrapped>.just(value)
        }
    }
}
