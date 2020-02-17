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
    
    func multipeered<T>() -> MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>]>
    where A == Observable<Meta<T>>, C == [Observable<(Meta<T>, Moment)>] {
        .init(
            value: value,
            get: { values in (
                self.get,
                MultipeerJSON().rendering(Observable.merge(self.set).map { $0.1 }) { multipeer, state in
                    multipeer.render(state.coerced() as [AnyHashable: Any])
                }
            )},
            set: { _, _ in self.set.map { $0.map { $0.0 } } }
        )
    }
    
    func multipeered<T>() -> MutatingLens<A, (B, MultipeerJSON), C>
    where A == Observable<Meta<T>>, C == [Observable<(Meta<T>, Moment)>] {
        .init(
            value: value,
            get: { values in (
                self.get,
                MultipeerJSON().rendering(Observable.merge(self.set).map { $0.1 }) { multipeer, state in
                    multipeer.render(state.coerced() as [AnyHashable: Any])
                }
            )},
            set: { _, _ in self.set }
        )
    }
    
    func bugReported<T>(when: @escaping (T) -> Bool = { _ in false })
        -> MutatingLens<A, (B, BugReporter), [Observable<Meta<T>>]>
        where A == Observable<Meta<T>>, C == [Observable<(Meta<T>, Moment)>]
    {
        .init(
            value: value,
            get: { values in (
                self.get,
                BugReporter(
                    initial: .init(state: .idle)
                )
                .rendering(
                    Observable
                        .merge(self.set)
                        .share()
                        .filter { when($0.0.value) }
                        .last(25)
                        .map { xs in
                            BugReporter.Model(
                                state: xs
                                    .map { $0.1 }
                                    .eventsPlayable
                                    .binaryPropertyList()
                                    .map(BugReporter.Model.State.sending)
                                    ?? .idle
                            )
                        }
                        .observeOn(MainScheduler()),
                    f: { reporter, state in
                        reporter.render(state)
                    }
                )
            )},
            set: { _, _ in self.set.map { $0.map { $0.0 } } }
        )
    }
    
    func momented<T>() -> MutatingLens<A, B, [Observable<(Meta<T>, Moment)>]>
    where A == Observable<Meta<T>>, C == [Labeled<Observable<Meta<T>>>] {
        .init(
            value: value,
            get: { _ in self.get },
            set: { _, _ in
                Observable
                    .merge(self.set.map { $0.value }.sourceTagged())
                    .map { state in (
                        state.1,
                        Moment(
                            drivers: NonEmptyArray(
                                possible: self
                                    .set
                                    .map { $0.label }
                                    .enumerated()
                                    .map { x in
                                        Moment.Driver(
                                            label: x.element,
                                            action: x.offset == state.0
                                                ? state.1.summary.cause.action :
                                                "",
                                            id: String(x.offset)
                                        )
                                    }
                            )!,
                            frame: state.1.summary.setting(
                                cause: state.1.summary.cause.setting(
                                    id: String(state.0)
                                )
                            )
                        )
                    )}
            }
        )
    }
}

private extension Collection {
    func sourceTagged<T>() -> [Observable<(tag: Int, element: T)>] where Element == Observable<T> {
        enumerated().map { indexed in
            indexed.element.map { x in (indexed.offset, x) }
        }
    }
}
