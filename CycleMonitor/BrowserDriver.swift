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

class BrowserDriver {
  
  struct Model {
    enum State {
      case idle
      case saving([AnyHashable: Any])
      case opening
    }
    var state: State
  }
  
  enum Action {
    case none
    case saving
    case opening(URL)
    case didOpen([AnyHashable: Any])
  }
  
  var model: Model
  var output = BehaviorSubject<Action>(value: .none)
  private var cleanup = DisposeBag()

  required init(initial: Model) {
    model = initial
  }
  
  static var open: NSOpenPanel {
    let x = NSOpenPanel()
    x.allowsMultipleSelection = false
    x.canChooseDirectories = false
    x.canCreateDirectories = false
    x.canChooseFiles = true
    return x
  }
  
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input.subscribe {
      if let element = $0.element {
        DispatchQueue.main.async {
          let old = self.model
          self.model = element
          self.render(
            old: old,
            new: element
          )
        }
      }
    }.disposed(by: cleanup)
    return output
  }
  
  func render(old: Model, new: Model) {
    if new != old {
      switch new.state {
      case .opening:
        let open = BrowserDriver.open
        if open.runModal() == NSModalResponseOK {
          open.url
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
            >>- Event.next
            >>- output.on
        }
      case .saving(let json):
        let save = NSSavePanel()
        if save.runModal() == NSModalResponseOK {
          save.url
            >>- {
              try? PropertyListSerialization.data(
                fromPropertyList: json,
                format: .binary,
                options: 0
              )
              .write(to: $0)
            }
        }
      case .idle:
        break
      }
    }
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
    default:
      return false
    }
  }
}
