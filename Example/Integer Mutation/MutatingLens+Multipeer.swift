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
    ) -> MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>]>
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
        
            return MutatingLens<A, (B, MultipeerJSON), [Observable<Meta<T>>]>(
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
}

private extension Collection {
    func tagged<T>() -> [Observable<(tag: Int, element: T)>] where Element == Observable<T> {
        enumerated().map { indexed in
            indexed.element.map { x in (indexed.offset, x) }
        }
    }
}
