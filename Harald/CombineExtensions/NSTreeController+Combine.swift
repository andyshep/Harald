//
//  NSTreeController+Combine.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Cocoa
import Combine

extension NSTreeController {
    var selectionIndexPathsPublisher: AnyPublisher<[IndexPath], Never> {
        return KeyValueObservingPublisher(
            object: self,
            keyPath: \.selectionIndexPaths,
            options: [.new]
        )
        .eraseToAnyPublisher()
    }
}
