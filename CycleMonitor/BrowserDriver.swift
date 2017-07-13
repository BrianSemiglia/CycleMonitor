//
//  BrowserDriver.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/13/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import AppKit
import RxSwift

class BrowserDriver {
  
  struct Model {
    enum State {
      case idle
      case saving
      case opening
    }
    var state: State
  }
  
  enum Action {
    case none
    case saving
    case opening(URL)
    case didOpen
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
        let x = open.runModal()
        if x == NSModalResponseOK {
          let directory = open.directoryURL
          let filename = open.representedFilename
        }
        output.on(.next(.didOpen))
      case .saving:
        let save = NSSavePanel()
        let x = save.runModal()
        if x == NSModalResponseOK {
          let directory = save.directoryURL
          let filename = save.representedFilename
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
