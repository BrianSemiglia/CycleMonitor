//
//  CycleMonitorEvent.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 9/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

struct Meta<T: Equatable>: Equatable {
    let value: T
    let summary: Moment.Frame
}

struct Labeled<T> {
    var value: T
    let label: String
}

public struct Moment: Equatable {
    
    public struct Driver: Equatable {
        var label: String
        var action: String
        var id: String
    }
    
    public struct Frame: Equatable {
        var cause: Driver
        var effect: String
        var context: String
        var isApproved: Bool
        
        public init(
            cause: Driver,
            effect: String,
            context: String,
            isApproved: Bool
        ) {
            self.cause = cause
            self.effect = effect
            self.context = context
            self.isApproved = isApproved
        }
    }

    var drivers: [Driver]
    var frame: Frame
    
    init(
        drivers: NonEmptyArray<Driver>,
        frame: Frame
    ) {
        self.drivers = drivers.value
        self.frame = frame
    }
}

struct NonEmptyArray<T> {
  let value: [T]
  init(_ values: T...) {
    self.init(possible: values)!
  }
  init?(possible: [T]) {
    if possible.count > 0 {
      value = possible
    } else {
      return nil
    }
  }
}

extension String {
  var valid: String? {
    count == 0
      ? nil
      : self
  }
}

extension Moment.Driver {
  func coerced() -> [AnyHashable: Any] { [
    "label": label,
    "action": action,
    "id": id
  ]}
}

extension Moment {
  func coerced() -> [AnyHashable: Any] { [
    "drivers": drivers.map { $0.coerced() as [AnyHashable: Any] },
    "cause": frame.cause.coerced() as [AnyHashable: Any],
    "context": frame.context,
    "effect": frame.effect
  ]}
}
