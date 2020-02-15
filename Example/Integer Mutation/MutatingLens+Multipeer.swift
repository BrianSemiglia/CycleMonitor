//
//  MutatingLens+Multipeer.swift
//  Integer Mutation
//
//  Created by Brian Semiglia on 2/8/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import RxSwift
import Cycle

extension MutatingLens {

    func multipeered<T>(
        reducer: @escaping (T, Moment.Frame) -> T = { t, m in t }
    ) -> MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>], Tag>
    where A == Observable<Meta<T>>, C == [Labeled<Observable<Meta<T>>>] {
        
        let moments = Observable
            .merge(self.set.map { $0.value }.tagged())
            .map { ($0.tag, $0.1.summary) }
            .map { states -> Moment in
                Moment(
                    drivers: NonEmptyArray(
                        possible: self.set.map { $0.label }.enumerated().map { x in
                            Moment.Driver(
                                label: x.element,
                                action: x.offset == states.0 ? states.1.cause.action : "", //
                                id: String(x.offset)
                            )
                        }
                    )!,
                    frame: states.1.setting(
                        cause: states.1.cause.setting(
                            id: String(states.0)
                        )
                    )
                )
            }
        
            return MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>], Tag>(
                value: value,
                get: { values in (
                    self.get,
                    MultipeerJSON().rendering(moments) { multipeer, state in
                        multipeer.render(state.coerced() as [AnyHashable: Any])
                    }
                )},
                set: { _, _ in self.set.map { $0.value } }
            )
    }
    
    func multipeered<T>() -> MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>], Tag>
    where A == Observable<Meta<T>>, C == ([Observable<Meta<T>>], Observable<Moment>) {
        MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>], Tag>(
            value: value,
            get: { values in (
                self.get,
                MultipeerJSON().rendering(self.set.1) { multipeer, state in
                    multipeer.render(state.coerced() as [AnyHashable: Any])
                }
            )},
            set: { _, _ in self.set.0 }
        )
    }
    
    func multipeered<T>() -> MutatingLens<A, (B, MultipeerJSON), C, Tag>
    where A == Observable<Meta<T>>, C == ([Observable<Meta<T>>], Observable<Moment>) {
        MutatingLens<A, (B, MultipeerJSON), C, Tag>(
            value: value,
            get: { values in (
                self.get,
                MultipeerJSON().rendering(self.set.1) { multipeer, state in
                    multipeer.render(state.coerced() as [AnyHashable: Any])
                }
            )},
            set: { _, _ in self.set }
        )
    }
    
    func bugReported<T>(when: @escaping (T) -> Bool = { _ in false })
        -> MutatingLens<A, (B, BugReporter), [Observable<Meta<T>>], Tag>
        where A == Observable<Meta<T>>, C == ([Observable<Meta<T>>], Observable<Moment>)
    {
        MutatingLens<A, (B, BugReporter), [Observable<Meta<T>>], Tag>(
            value: value,
            get: { values in (
                self.get,
                BugReporter(
                    initial: .init(state: .idle)
                )
                .rendering(
                    Observable
                        .merge(self.set.0)
                        .map { $0.value }
                        .filter(when)
                        .map { _ in }.flatMap {
                            self
                            .set
                            .1
                            .last(25)
                            .map { xs -> BugReporter.Model in
                                BugReporter.Model(
                                    state: xs
                                        .eventsPlayable
                                        .binaryPropertyList()
                                        .map(BugReporter.Model.State.sending)
                                        ?? .idle
                                )
                            }
                        },
                    f: { reporter, state in
                        reporter.render(state)
                    }
                )
            )},
            set: { _, _ in self.set.0 }
        )
    }
    
    func momented<T>(
        reducer: @escaping (T, Moment.Frame) -> T = { t, m in t }
    ) -> MutatingLens<A, B, ([Observable<Meta<T>>], Observable<Moment>), Tag>
    where A == Observable<Meta<T>>, C == [Labeled<Observable<Meta<T>>>] {
        MutatingLens<A, B, ([Observable<Meta<T>>], Observable<Moment>), Tag>(
            value: value,
            get: { _ in self.get },
            set: { _, _ in (
                self.set.map { $0.value },
                Observable
                    .merge(self.set.map { $0.value }.tagged())
                    .map { ($0.tag, $0.1.summary) }
                    .map { states in
                        Moment(
                            drivers: NonEmptyArray(
                                possible: self.set.map { $0.label }.enumerated().map { x in
                                    Moment.Driver(
                                        label: x.element,
                                        action: x.offset == states.0 ? states.1.cause.action : "",
                                        id: String(x.offset)
                                    )
                                }
                                )!,
                            frame: states.1.setting(
                                cause: states.1.cause.setting(
                                    id: String(states.0)
                                )
                            )
                        )
                    }
            )}
        )
    }
}

private extension Collection {
    func tagged<T>() -> [Observable<(tag: Int, element: T)>] where Element == Observable<T> {
        enumerated().map { indexed in
            indexed.element.map { x in (indexed.offset, x) }
        }
    }
}
