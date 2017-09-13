//
//  CycleMonitorTests.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 9/5/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import XCTest
@testable import CycleMonitor
@testable import Argo
@testable import Curry
@testable import Runes

class CycleMonitorTests: XCTestCase {
  
  static var saveFileSuccess: [AnyHashable: Any] { return
    [
      "drivers": [
        [
          "label": "a-label",
          "action": "a-action",
          "id": "a-id"
        ],
        [
          "label": "b-label",
          "action": "",
          "id": "b-id"
        ],
        [
          "label": "c-label",
          "action": "",
          "id": "c-id"
        ]
      ],
      "cause": [
        "label": "a-label",
        "action": "a-action",
        "id": "a-id"
      ],
      "effect": "effect",
      "context": "context",
      "pendingEffectEdit": "pendingEffectEdit"
    ]
  }
  
  static var saveFileDriversEmpty: [AnyHashable: Any] { return
    [
      "drivers": [],
      "cause": [
        "label": "a-label",
        "action": "a-action",
        "id": "a-id"
      ],
      "effect": "effect",
      "context": "context",
      "pendingEffectEdit": "pendingEffectEdit"
    ]
  }
  
  static var saveFileEmptyPendingEffectEdit: [AnyHashable: Any] { return
    [
      "drivers": [
        [
          "label": "a-label",
          "action": "a-action",
          "id": "a-id"
        ],
        [
          "label": "b-label",
          "action": "",
          "id": "b-id"
        ],
        [
          "label": "c-label",
          "action": "",
          "id": "c-id"
        ]
      ],
      "cause": [
        "label": "a-label",
        "action": "a-action",
        "id": "a-id"
      ],
      "effect": "effect",
      "context": "context",
      "pendingEffectEdit": ""
    ]
  }
  
  static var testFileSuccess: [AnyHashable: Any] { return
    [
      "drivers": [
        [
          "label": "a-label",
          "action": "a-action",
          "id": "a-id"
        ],
        [
          "label": "b-label",
          "action": "",
          "id": "b-id"
        ],
        [
          "label": "c-label",
          "action": "",
          "id": "c-id"
        ]
      ],
      "cause": [
        "label": "a-label",
        "action": "a-action",
        "id": "a-id"
      ],
      "effect": "effect",
      "context": "context"
    ]
  }
  
  static var eventEmptyPendingEffect: Event? { return
    curry(Event.init(drivers:cause:effect:context: pendingEffectEdit:))
      <^> NonEmptyArray(possible: [
        Event.Driver(
          label: "label",
          action: "action",
          id: "id"
        )
      ])
      <*> Event.Driver(
        label: "label",
        action: "action",
        id: "id"
      )
      <*> ""
      <*> "context"
      <*> ""
  }
  
  func testSaveFile() {
    
    // should decode
    XCTAssertNotEqual(
      decode(CycleMonitorTests.testFileSuccess) as Event?,
      nil
    )
    
    // should have at least one driver
    XCTAssertEqual(
      decode(CycleMonitorTests.saveFileDriversEmpty) as Event?,
      nil
    )
    
    // Should resolve empty-string pending-effect-edit to nil
    XCTAssertEqual(
      CycleMonitorTests.eventEmptyPendingEffect?.pendingEffectEdit,
      nil
    )
  }
  
}
