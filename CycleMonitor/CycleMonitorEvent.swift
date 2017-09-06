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
  var pendingEffectEdit: String?
  var isApproved = false
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
