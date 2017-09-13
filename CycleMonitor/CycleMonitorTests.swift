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
  
  static var eventDriverValid: [AnyHashable: Any] { return
    [
      "label": "a-label",
      "action": "a-action",
      "id": "a-id"
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
  
  static var eventSuccess: Event? { return
    curry(Event.init(drivers:cause:effect:context: pendingEffectEdit:))
      <^> NonEmptyArray(possible: [
        Event.Driver(
          label: "a-label",
          action: "a-action",
          id: "a-id"
        ),
        Event.Driver(
          label: "b-label",
          action: "",
          id: "b-id"
        ),
        Event.Driver(
          label: "c-label",
          action: "",
          id: "c-id"
        )
      ])
      <*> Event.Driver(
        label: "a-label",
        action: "a-action",
        id: "a-id"
      )
      <*> "effect"
      <*> "context"
      <*> "pendingEffectEdit"
  }
  
  func testSaveFile() {
    
    // should decode event
    XCTAssertNotEqual(
      decode(CycleMonitorTests.testFileSuccess) as Event?,
      nil
    )
    
    // should decode event driver
    XCTAssertNotEqual(
      decode(CycleMonitorTests.eventDriverValid) as Event.Driver?,
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
    
    // should encode event
    XCTAssertEqual(
      CycleMonitorTests.eventSuccess
        .map { $0.coerced() as [AnyHashable: Any] }
        .map (NSDictionary.init)
      ,
      .some(
        NSDictionary(
          dictionary: CycleMonitorTests.saveFileSuccess
        )
      )
    )
  }
  
}
