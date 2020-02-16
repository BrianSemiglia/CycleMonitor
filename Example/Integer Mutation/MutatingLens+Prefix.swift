//
//  MutatingLens+Prefix.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/15/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import RxSwift
import Cycle

extension MutatingLens {
    func prefixed<T>(with prefix: T) -> MutatingLens<A, B, C> where C == [Labeled<Observable<Meta<T>>>] {
        .init(
            value: value,
            get: { _ in self.get },
            set: { _, _ in
                self.set.enumerated().map {
                    if $0.offset == self.set.count - 1 {
                        var new = $0.element
                        new.value = new.value.startWith(
                            Meta(
                                value: prefix,
                                summary: Moment.Frame(
                                    cause: Moment.Driver( // needs fix. driver not correct. possibly keep moments outside of state stream.
                                        label: "",
                                        action: "",
                                        id: ""),
                                    effect: "",
                                    context: "",
                                    isApproved: false
                                )
                            )
                        )
                        return new
                    } else {
                        return $0.element
                    }
                }
            }
        )
    }
    
    func prefixed<T>(with prefix: T) -> MutatingLens<A, B, C> where C == [Observable<Meta<T>>] {
        .init(
            value: value,
            get: { _ in self.get },
            set: { _, _ in
                self.set.enumerated().map {
                    if $0.offset == self.set.count - 1 {
                        var new = $0.element
                        new = new.startWith(
                            Meta(
                                value: prefix,
                                summary: Moment.Frame(
                                    cause: Moment.Driver( // needs fix. driver not correct. possibly keep moments outside of state stream.
                                        label: "",
                                        action: "",
                                        id: ""),
                                    effect: "",
                                    context: "",
                                    isApproved: false
                                )
                            )
                        )
                        return new
                    } else {
                        return $0.element
                    }
                }
            }
        )
    }
}
