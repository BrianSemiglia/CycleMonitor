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
        reducer: @escaping (Element, Driver.Event) -> Element
    ) -> MutatingLens<Observable<Element>, Driver, Observable<Element>> where Element == Driver.Model {
        lens(
            get: { (states: Observable<Element>) -> Driver in
                driver.rendering(states) { driver, state in
                    driver.render(state)
                }
            },
            set: { toggler, state -> Observable<Element> in
                toggler
                    .events()
                    .tupledWithLatestFrom(state)
                    .map { ($0.1, $0.0) }
                    .map(reducer)
            }
        )
    }
    
    func lens<T, Driver: Drivable>(
        lifter: @escaping (T) -> Driver.Model, // Need to figure out getting subset from source -> MutatingLens wants same type on incoming stream
        driver: Driver,
        reducer: @escaping (Element, Driver.Event) -> T
    )
    -> MutatingLens<Observable<Element>, Driver, Observable<Element>>
        where Element == Meta<T> {
        lens(
            get: { (state: Observable<Element>) -> Driver in
                driver.rendering(state.map { $0.value }.map(lifter)) { driver, state in
                    driver.render(state)
                }
            },
            set: { driver, state -> Observable<Element> in
                driver
                    .events()
                    .tupledWithLatestFrom(state.map { $0 })
                    .map { (old: $0.1, event: $0.0, new: reducer($0.1, $0.0)) }
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
                    }
            }
        )
    }
    
    func lens<T, Driver: Drivable>(
        lifter: @escaping (T) -> Driver.Model, // Need to figure out getting subset from source -> MutatingLens wants same type on incoming stream
        driver: Driver,
        reducer: @escaping (T, Driver.Event) -> T
    )
    -> MutatingLens<
        Observable<Element>,
        Driver,
        Observable<Element>
    > where Element == Meta<T> {
        lens(
            get: { state in
                driver.rendering(state.map { $0.value }.map(lifter)) { driver, state in
                    driver.render(state)
                }
            },
            set: { driver, state  in
                driver
                    .events()
                    .tupledWithLatestFrom(state)
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
                    }
            }
        )
    }
}
