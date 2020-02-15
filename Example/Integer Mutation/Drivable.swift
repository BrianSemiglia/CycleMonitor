//
//  Drivable.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/8/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import Cycle
import RxSwift

public protocol Drivable: NSObject {
    associatedtype Model
    associatedtype Event
    func render(_ input: Model)
    func events() -> Observable<Event>
}

extension Observable {
    public func lens<Driver: Drivable>(
        driver: Driver,
        drivenOn: ImmediateSchedulerType = MainScheduler(),
        reducer: @escaping (Element, Driver.Event) -> Element,
        reducedOn: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .userInteractive)
    ) -> MutatingLens<Observable<Element>, Driver, [Observable<Element>]> where Element == Driver.Model {
        lens(
            get: { states in
                driver.rendering(states.observeOn(drivenOn)) { driver, state in
                    driver.render(state)
                }
            },
            set: { toggler, state in
                toggler
                    .events()
                    .tupledWithLatestFrom(state)
                    .observeOn(reducedOn)
                    .map { reducer($0.1, $0.0) }
            }
        )
    }
            
    func lens<Driver: Drivable>(
        lifter: @escaping (Element) -> Driver.Model,
        driver: Driver,
        drivenOn: ImmediateSchedulerType = MainScheduler(),
        reducer: @escaping (Element, Driver.Event) -> Element,
        reducedOn: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .userInteractive)
    ) -> MutatingLens<Observable<Element>, Driver, [Observable<Element>]> {
        lens(
            get: { states in
                driver.rendering(states.map(lifter).observeOn(drivenOn)) { driver, state in
                    driver.render(state)
                }
            },
            set: { toggler, state in
                toggler
                    .events()
                    .tupledWithLatestFrom(state)
                    .observeOn(reducedOn)
                    .map { reducer($0.1, $0.0) }
            }
        )
    }
    
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
