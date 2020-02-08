//
//  BrowserDriver.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/13/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import AppKit
import Foundation
import RxSwift
import Runes

class BrowserDriver: NSObject {
  
  struct Model {
    enum State {
      case idle
      case saving([AnyHashable: Any])
      case savingMany([[AnyHashable: Any]])
      case opening
    }
    var state: State
  }
  
  enum Action {
    case none
    case saving
    case opening(URL)
    case didOpen([AnyHashable: Any])
    case cancelling
  }
  
  var model: Model
  var output = BehaviorSubject<Action>(value: .none)
  private var cleanup = DisposeBag()

  required init(initial: Model) {
    model = initial
    super.init()
  }
  
  static var open: NSOpenPanel {
    let x = NSOpenPanel()
    x.allowsMultipleSelection = false
    x.canChooseDirectories = false
    x.canCreateDirectories = false
    x.canChooseFiles = true
    return x
  }
  
  static var selectDirectory: NSOpenPanel {
    let x = NSOpenPanel()
    x.allowsMultipleSelection = false
    x.canChooseDirectories = true
    x.canCreateDirectories = true
    x.canChooseFiles = false
    return x
  }
  
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input
      .observeOn(MainScheduler.instance)
      .subscribe(
        onNext: {
          let old = self.model
          self.model = $0
          self.render(
            old: old,
            new: $0
          )
        }
      )
      .disposed(by: cleanup)
    return output
  }
  
  func render(old: Model, new: Model) {
    if new != old {
      switch new.state {
      case .opening:
        let open = BrowserDriver.open
        if open.runModal() == .OK {
          let event = open.url
            >>- { try? Data(contentsOf: $0) }
            >>- {
              try? PropertyListSerialization.propertyList(
                from: $0,
                options: PropertyListSerialization.MutabilityOptions(rawValue: 0),
                format: nil
              )
            }
            >>- { $0 as? [AnyHashable: Any] }
            >>- Action.didOpen
            >>- RxSwift.Event.next
          if let event = event {
            output.on(event)
          }
        } else {
          output.on(.next(.cancelling))
        }
      case .saving(let json):
        let save = NSSavePanel()
        if save.runModal() == .OK, let url = save.url, let data = json.binaryPList {
          try? data.write(to: url)
        }
      case .savingMany(let JSONs):
        
        /* TODO: reconsider visual presentation of unit: (context, event, effect)
         */
        
        let save = BrowserDriver.selectDirectory
        if save.runModal() == .OK, let url = save.directoryURL {
          
          let saves = JSONs
            .enumerated()
            .compactMap { x -> (String, Data)? in
              if let data = x.element.binaryPList {
                return (
                  Date().description + String(describing: x.offset),
                  data
                )
              } else {
                return nil
              }
            }
          
          saves.forEach {
            try? $0.1.write(
              to: URL(
                fileURLWithPath: url
                  .appendingPathComponent($0.0)
                  .appendingPathExtension("moment")
                  .path
              )
            )
          }
          output.on(.next(.none))
        }
      case .idle:
        break
      }
    }
  }
}

extension Collection where Iterator.Element == (key: AnyHashable, value: Any) {
  var binaryPList: Data? {
    try? PropertyListSerialization.data(
      fromPropertyList: self,
      format: .binary,
      options: 0
    )
  }
}

extension BrowserDriver.Model: Equatable {
  static func ==(left: BrowserDriver.Model, right: BrowserDriver.Model) -> Bool {
    return left.state == right.state
  }
}

extension BrowserDriver.Model.State: Equatable {
  static func ==(
    left: BrowserDriver.Model.State,
    right: BrowserDriver.Model.State
  ) -> Bool {
    switch (left, right) {
    case (.idle, .idle):
      return true
    case (.saving(let a), .saving(let b)):
      return NSDictionary(dictionary: a) == NSDictionary(dictionary: b)
    case (.opening, .opening):
      return true
    case (.savingMany(let a), .savingMany(let b)):
      return a.map(NSDictionary.init) == b.map(NSDictionary.init)
    default:
      return false
    }
  }
}
