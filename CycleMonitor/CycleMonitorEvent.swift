//
//  CycleMonitorEvent.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 9/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

struct Event {
  struct Driver {
    var label: String
    var action: String
    var id: String
  }
  var drivers: [Driver]
  var cause: Driver
  var effect: String
  var context: String
  var pendingEffectEdit: String? { // TODO: Make private to CycleMonitor
    didSet {
      pendingEffectEdit = pendingEffectEdit?.valid
    }
  }
  var isApproved = false
  init(
    drivers: NonEmptyArray<Driver>,
    cause: Driver,
    effect: String,
    context: String,
    pendingEffectEdit: String?,
    isApproved: Bool
  ) {
    self.drivers = drivers.value
    self.cause = cause
    self.effect = effect
    self.context = context
    self.pendingEffectEdit = pendingEffectEdit?.valid
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

extension Event {
  init(
    drivers: NonEmptyArray<Event.Driver>,
    cause: Event.Driver,
    effect: String,
    context: String,
    pendingEffectEdit: String?
  ) {
    self = Event(
      drivers: drivers,
      cause: cause,
      effect: effect,
      context: context,
      pendingEffectEdit: pendingEffectEdit,
      isApproved: false
    )
  }
}

extension String {
  var valid: String? { return
    characters.count == 0
      ? nil
      : self
  }
}

extension Event: Equatable {
  static func ==(left: Event, right: Event) -> Bool { return
    left.drivers == right.drivers &&
    left.cause == right.cause &&
    left.effect == right.effect &&
    left.context == right.context &&
    left.pendingEffectEdit == right.pendingEffectEdit &&
    left.isApproved == right.isApproved
  }
}

extension Event.Driver: Equatable {
  static func ==(left: Event.Driver, right: Event.Driver) -> Bool { return
    left.action == right.action &&
    left.id == right.id &&
    left.label == right.label
  }
}

extension Event.Driver {
  var JSON: [AnyHashable: Any] { return [
    "label": label,
    "action": action,
    "id": id
    ]}
}

extension Event {
  var JSON: [AnyHashable: Any] { return [
    "drivers": drivers.map { $0.JSON },
    "cause": cause.JSON,
    "context": context,
    "effect": effect
    ]}
}
