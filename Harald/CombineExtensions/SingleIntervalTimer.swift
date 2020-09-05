//
//  SingleIntervalTimer.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine

public final class SingleIntervalTimer {
    private let startDate = Date()
    private let interval: TimeInterval
    private let timerSubject: PassthroughSubject<TimeInterval, Never>
    
    private lazy var timer: Timer = {
        return Timer(
            timeInterval: interval,
            target: self, selector:
            #selector(timerDidFire(_:)),
            userInfo: nil,
            repeats: false
        )
    }()
    
    init(interval: TimeInterval) {
        self.interval = interval
        self.timerSubject = PassthroughSubject<TimeInterval, Never>()
        
        RunLoop.main.add(timer, forMode: .common)
    }
    
    deinit {
        timer.invalidate()
    }
    
    @objc private func timerDidFire(_ timer: Timer) {
        let interval = Date().timeIntervalSince(startDate)
        timerSubject.send(interval)
    }
}

extension SingleIntervalTimer: Publisher {
    public typealias Output = TimeInterval
    public typealias Failure = Never
    
    public func receive<S>(subscriber: S) where S : Subscriber, SingleIntervalTimer.Failure == S.Failure, SingleIntervalTimer.Output == S.Input {
        timerSubject.subscribe(subscriber)
    }
}
