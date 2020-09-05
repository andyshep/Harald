//
//  RepeatableIntervalTimer.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine

public final class RepeatableIntervalTimer {
    private let startDate = Date()
    private let interval: TimeInterval
    private let timerSubject: PassthroughSubject<TimeInterval, Never>
    
    private lazy var timer: Timer = {
        return Timer(
            fireAt: startDate,
            interval: interval,
            target: self,
            selector: #selector(timerDidFire(_:)),
            userInfo: nil,
            repeats: true
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

extension RepeatableIntervalTimer: Publisher {
    public typealias Output = TimeInterval
    public typealias Failure = Never
    
    public func receive<S>(subscriber: S) where S : Subscriber, RepeatableIntervalTimer.Failure == S.Failure, RepeatableIntervalTimer.Output == S.Input {
        timerSubject.subscribe(subscriber)
    }
}
