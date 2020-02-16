//
//  Drivable+Meta.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/15/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import RxSwift
import Cycle

extension Observable {
    func lens<T, Driver: Drivable>(
        label: String? = nil,
        lifter: @escaping (T) -> Driver.Model,
        driver: Driver,
        drivenOn: ImmediateSchedulerType = MainScheduler(),
        reducer: @escaping (T, Driver.Event) -> T,
        reducedOn: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .userInteractive)
    ) -> MutatingLens<Observable<Element>, Driver, [Labeled<Observable<Element>>]> where Element == Meta<T> {
        lens(
            get: { states in
                driver.rendering(states.map { $0.value }.map(lifter).observeOn(drivenOn)) { driver, state in
                    driver.render(state)
                }
            },
            set: { driver, state in
                Labeled(
                    value: driver
                    .events()
                    .tupledWithLatestFrom(state)
                    .observeOn(reducedOn)
                    .map { (old: $0.1, event: $0.0, new: reducer($0.1.value, $0.0)) }
                    .map {
                        Meta(
                            value: $0.new,
                            summary: Moment.Frame(
                                cause: Moment.Driver(
                                    label: "\(type(of: driver))",
                                    action: "\($0.event)",
                                    id: ""
                                ),
                                effect: sourceCode($0.new),
                                context: sourceCode($0.old.value),
                                isApproved: false
                            )
                        )
                    },
                    label: label ?? "\(type(of: driver))"
                )
            }
        )
    }
}
