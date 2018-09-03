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
  
  static func eventSuccess() -> Moment? { return
    curry(Moment.init(drivers:cause:effect:context:))
      <^> NonEmptyArray(possible: [
        driverWith(id: "a", action: true),
        driverWith(id: "b", action: false),
        driverWith(id: "c", action: false)
      ])
      <*> driverWith(id: "a", action: true)
      <*> "effect"
      <*> "context"
  }
  
  static func eventSuccess() -> [AnyHashable: Any] { return
    [
      "drivers": [
        driverWith(id: "a", action: true) as [AnyHashable: Any],
        driverWith(id: "b", action: false) as [AnyHashable: Any],
        driverWith(id: "c", action: false) as [AnyHashable: Any]
      ],
      "cause": driverWith(id: "a", action: true) as [AnyHashable: Any],
      "effect": "effect",
      "context": "context",
    ]
  }
  
  static var saveFileSuccess: [AnyHashable: Any] { return
    [
      "drivers": [
        driverWith(id: "a", action: true) as [AnyHashable: Any],
        driverWith(id: "b", action: false) as [AnyHashable: Any],
        driverWith(id: "c", action: false) as [AnyHashable: Any]
      ],
      "cause": driverWith(id: "a", action: true) as [AnyHashable: Any],
      "effect": "effect",
      "context": "context"
    ]
  }
  
  static var saveFileDriversEmpty: [AnyHashable: Any] { return
    [
      "drivers": [],
      "cause": driverWith(id: "a", action: true) as [AnyHashable: Any],
      "effect": "effect",
      "context": "context"
    ]
  }
  
  static var eventDriverValid: [AnyHashable: Any] { return
    driverWith(id: "a", action: true)
  }
  
  static var testFileSuccess: [AnyHashable: Any] { return
    [
      "drivers": driversJSON,
      "cause": driversJSON.first!,
      "effect": "effect",
      "context": "context"
    ]
  }
  
  static var driversJSON: [[AnyHashable: Any]] { return
    [
      driverWith(id: "a", action: true),
      driverWith(id: "b", action: false),
      driverWith(id: "c", action: false)
    ]
  }
  
  static var drivers: [Moment.Driver] { return
    [
      driverWith(id: "a", action: true),
      driverWith(id: "b", action: false),
      driverWith(id: "c", action: false)
    ]
  }
  
  static func driverWith(id: String, action: Bool) -> Moment.Driver { return
    Moment.Driver(
      label: id + "-label",
      action: action ? id + "-action" : "",
      id: id + "-id"
    )
  }

  static func driverWith(id: String, action: Bool) -> [AnyHashable: Any] { return
    [
      "label": id + "-label",
      "action": action ? id + "-action" : "",
      "id": id + "-id"
    ]
  }
  
  static func model() -> CycleMonitorApp.Model { return
    CycleMonitorApp.Model(
      events: eventSuccess()
        .map { [$0] as [Moment] }
        ?? [],
      timeLineView: CycleMonitorApp.Model.TimeLineView(
        selectedIndex: 0
      ),
      multipeer: CycleMonitorApp.Model.Connection.disconnected,
      application: AppDelegateStub.Model(),
      browser: BrowserDriver.Model(
        state: .idle
      ),
      menuBar: MenuBarDriver.Model(
        items: []
      ),
      eventHandlingState: CycleMonitorApp.Model.EventHandlingState.playing,
      isTerminating: false,
      devices: [],
      selectedPeer: nil
    )
  }
  
  static func timelineFile() -> [AnyHashable: Any] { return
    [
      "selectedIndex": 0,
      "events": [eventSuccess() as [AnyHashable: Any]]
    ]
  }

  static func timelineFileNoSelectedIndex() -> [AnyHashable: Any] { return
    [
      "selectedIndex": "",
      "events": [eventSuccess() as [AnyHashable: Any]]
    ]
  }
  
  static func timelineViewNoSelectedIndex() -> CycleMonitorApp.Model.TimeLineView { return
    CycleMonitorApp.Model.TimeLineView(
      selectedIndex: nil
    )
  }
  
  func testSaveFile() {
    
    // should decode event
    XCTAssertNotEqual(
      decode(CycleMonitorTests.testFileSuccess) as Moment?,
      nil
    )
    
    // should decode event driver
    XCTAssertNotEqual(
      decode(CycleMonitorTests.eventDriverValid) as Moment.Driver?,
      nil
    )
    
    // should have at least one driver
    XCTAssertEqual(
      decode(CycleMonitorTests.saveFileDriversEmpty) as Moment?,
      nil
    )
        
    // should encode event
    XCTAssertEqual(
      CycleMonitorTests.eventSuccess()
        .map { $0.playback() as [AnyHashable: Any] }
        .map (NSDictionary.init)
      ,
      NSDictionary(
        dictionary: CycleMonitorTests.eventSuccess()
      )
    )
    
    // should encode driver
    XCTAssertEqual(
      NSDictionary(
        dictionary: CycleMonitorTests
          .driverWith(id: "a", action: false)
          .coerced()
      ),
      NSDictionary(
        dictionary: CycleMonitorTests
          .driverWith(id: "a", action: false)
      )
    )
    
    // should encode timeline
    XCTAssertEqual(
      NSDictionary(
        dictionary:CycleMonitorTests.model().timelineFile
      ),
      NSDictionary(
        dictionary: CycleMonitorTests.timelineFile()
      )
    )
    
    // Should resolve empty-string selected-index to nil
    XCTAssertEqual(
      CycleMonitorApp.Model.TimeLineView.timelineViewFrom(
        CycleMonitorTests.timelineFileNoSelectedIndex()
      ),
      CycleMonitorTests.timelineViewNoSelectedIndex()
    )
  }
  
}
