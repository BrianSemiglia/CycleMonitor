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

extension Collection {
    func tagged<T>() -> [Observable<(tag: Int, element: T)>] where Element == Observable<T> {
        enumerated().map { indexed in
            indexed.element.map { x in (indexed.offset, x) }
        }
    }
}

extension MutatingLens {
    func multipeered<T>(
        reducer: @escaping (T, Moment.Frame) -> T = { t, m in t }
    ) -> MutatingLens<A, (B, MultipeerJSON), Observable<Debug<T>>>
        where A == Observable<Debug<T>>, C == Observable<Debug<T>> {
        
        let moments = Observable
            .merge(self.set.tagged())
            .map { ($0.tag, $0.1.frame) }
            .map { states in
                Moment(
                    drivers: NonEmptyArray(
                        possible: self.set.enumerated().map { x in
                            Moment.Driver(
                                label: "\(type(of: self.get))", // label is coming from combined lens (eg UIViewController). need inner lens labels
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
        
            return MutatingLens<A, (B, MultipeerJSON), Observable<Debug<T>>>(
                value: value,
                get: { values in (
                    self.get,
                    MultipeerJSON().rendering(moments) { multipeer, state in
                        multipeer.render(state.coerced() as [AnyHashable: Any])
                    }
                )},
                set: { _, _ in self.set }
            )
    }
}
