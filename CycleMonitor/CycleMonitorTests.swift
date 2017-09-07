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
  
  func testSaveFile() {
    XCTAssertNotEqual(
      decode(CycleMonitorTests.saveFileDriversEmpty) as Event?,
      nil
    )
    
    // should have at least one driver
    XCTAssertEqual(
      decode(CycleMonitorTests.saveFileDriversEmpty) as Event?,
      nil
    )
    
    // 1. should match cause and one driver
    // 2. move cause to `drivers` and add action flag?
    // 3. move monitor specific info to another scope of JSON payload?
  }
  
}
