//
//  Observable+Convenience.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/8/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType {
  func pacedBy(delay: Double) -> Observable<Element> { return
    map {
      Observable
        .empty()
        .delay(
          .milliseconds(Int(delay * 1000)),
          scheduler: MainScheduler.instance
        )
        .startWith($0)
    }
    .concat()
  }
}

extension ObservableType {
  func tupledWithLatestFrom<X, Y>(
    _ x: Observable<X>,
    _ y: Observable<Y>
  ) -> Observable<(Element, X, Y)> { return
    tupledWithLatestFrom(x)
      .tupledWithLatestFrom(y)
      .map { ($0.0, $0.1, $1) }
  }
  
  func tupledWithLatestFrom<T>(
    _ input: Observable<T>
  ) -> Observable<(Element, T)> { return
    withLatestFrom(input) { ($0, $1 ) }
  }
}

extension Observable {
  func secondToLast() -> Observable<Element?> { return
    last(2).map { $0.first }
  }
  func lastTwo() -> Observable<(Element?, Element)> { return
    last(2)
    .map {
      switch $0.count {
      case 1: return (nil, $0[0])
      case 2: return ($0[0], $0[1])
      default: abort()
      }
    }
  }
  func last(_ count: Int) -> Observable<[Element]> { return
    scan ([]) { $0 + [$1] }
    .map { $0.suffix(count) }
    .map (Array.init)
  }
}
