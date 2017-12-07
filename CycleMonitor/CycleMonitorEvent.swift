//
//  CycleMonitorEvent.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 9/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

struct Moment {
  struct Driver {
    var label: String
    var action: String
    var id: String
  }
  var drivers: [Driver]
  var cause: Driver
  var effect: String
  var context: String
  var isApproved = false
  init(
    drivers: NonEmptyArray<Driver>,
    cause: Driver,
    effect: String,
    context: String,
    isApproved: Bool
  ) {
    self.drivers = drivers.value
    self.cause = cause
    self.effect = effect
    self.context = context
    self.isApproved = isApproved
  }
}

struct NonEmptyArray<T> {
  let value: [T]
  init?(possible: [T]) {
    if possible.count > 0 {
      value = possible
    } else {
      return nil
    }
  }
}

extension Moment {
  init(
    drivers: NonEmptyArray<Moment.Driver>,
    cause: Moment.Driver,
    effect: String,
    context: String
  ) {
    self = Moment(
      drivers: drivers,
      cause: cause,
      effect: effect,
      context: context,
      isApproved: false
    )
  }
}

extension String {
  var valid: String? { return
    count == 0
      ? nil
      : self
  }
}

extension Moment: Equatable {
  static func ==(left: Moment, right: Moment) -> Bool { return
    left.drivers == right.drivers &&
    left.cause == right.cause &&
    left.effect == right.effect &&
    left.context == right.context &&
    left.isApproved == right.isApproved
  }
}

extension Moment.Driver: Equatable {
  static func ==(left: Moment.Driver, right: Moment.Driver) -> Bool { return
    left.action == right.action &&
    left.id == right.id &&
    left.label == right.label
  }
}

extension Moment.Driver {
  func coerced() -> [AnyHashable: Any] { return [
    "label": label,
    "action": action,
    "id": id
  ]}
}

extension Moment {
  func playback() -> [AnyHashable: Any] { return [
    "drivers": drivers.map { $0.coerced() as [AnyHashable: Any] },
    "cause": cause.coerced() as [AnyHashable: Any],
    "context": context,
    "effect": effect
  ]}
}
