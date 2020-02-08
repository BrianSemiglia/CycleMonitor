//
//  Cycle-MacOS.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 1/18/20.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation
import RxSwift
//import RxOptional

struct Change<T> {
    let new: T
    let old: T?
}

extension Observable {
    func latestWithPrevious() -> Observable<Change<Element>> {
        previous(2).map { x -> Change<Element>? in
            switch x.count {
            case 1: return
                Change(
                    new: x.first!,
                    old: nil
                )
            case 2: return
                Change(
                    new: x[1],
                    old: x[0]
                )
            default: return
                .none
            }
        }
        .flatMap { x -> Observable<Change<Element>> in
            if let x = x {
                return Observable<Change<Element>>.just(x)
            } else {
                return Observable<Change<Element>>.never()
            }
        }
    }
    
    func previous(_ count: Int) -> Observable<[Element]> {
        scan (Array<Element>()) { $0 + [$1] }
            .map { $0.suffix(count) }
            .map (Array.init)
    }
}

extension ObservableType {
    func delayLatest(delay: RxTimeInterval, scheduler: SchedulerType) -> Observable<Element> {
        flatMapLatest {
            Observable
                .just($0)
                .delay(
                    delay,
                    scheduler: MainScheduler.instance
                )
        }
    }
}

extension Observable {
    public func ignoringCompletions() -> Observable {
        concat(Observable.never())
    }
}
