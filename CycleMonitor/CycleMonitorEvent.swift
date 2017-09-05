//
//  CycleMonitorEvent.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 9/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation

protocol CycleMonitorAppEvent {
  var drivers: [CycleMonitorAppEventDriver] { get }
  var cause: CycleMonitorAppEventDriver { get }
  var effect: String { get }
  var context: String { get }
  var pendingEffectEdit: String? { get }
  var isApproved: Bool { get }
}

protocol CycleMonitorAppEventDriver {
  var label: String { get }
  var action: String { get }
  var id: String { get }
}
