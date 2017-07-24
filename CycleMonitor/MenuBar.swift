//
//  MenuBar.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/16/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation
import AppKit
import RxSwift
import Runes

class MenuBarDriver {
  
  struct Model {
    struct MenuItem {
      let title: String
      let item: Item
    }
    struct Item {
      let title: String
      let enabled: Bool
      let id: String
    }
    let items: [Item]
  }
  
  enum Action {
    case none
    case didSelectItemWith(id: String)
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var ids: [Int: String] = [:]
  var model: Model {
    didSet {
      if model != oldValue {
        render(model)
      }
    }
  }
  
  init(model: Model) {
    self.model = model
    render(model)
  }
  
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input.observeOn(MainScheduler.instance).subscribe {
      if let new = $0.element, new != self.model {
        self.model = new
        self.render(new)
      }
    }.disposed(by: cleanup)
    return output
  }
  
  func render(_ input: Model) {
    let new: [NSMenuItem] = input.items.enumerated().map { index, item in
      return NSMenuItem(
        title: item.title,
        action: #selector(didReceiveEventFrom(_:)),
        target: self,
        keyEquivalent: "",
        tag: index
      )
    }
    
    ids = input.items.enumerated().reduce([:]) {
      var sum = $0.0
      sum[$0.1.offset] = $0.1.element.id
      return sum
    }
    
    let file = NSMenu(title: "File")
    let item = NSMenuItem()
    item.submenu = file
    new.forEach(file.addItem)
    
    let main = NSMenu(title: "Top")
    main.addItem(NSMenuItem.dud)
    main.addItem(item)
    NSApplication.shared().mainMenu = main
    
  }
  
  @objc func didReceiveEventFrom(_ menu: NSMenuItem) {
      ids[menu.tag]
        >>- Action.didSelectItemWith
        >>- Event.next
        >>- output.on
  }

}

extension NSMenuItem {
  static var dud: NSMenuItem {
    let dudMenu = NSMenu(title: "")
    let dud = NSMenuItem()
    dud.submenu = dudMenu
    return dud
  }
}

extension MenuBarDriver.Model: Equatable {
  static func ==(
    left: MenuBarDriver.Model,
    right: MenuBarDriver.Model
  ) -> Bool { return
    left.items == right.items
  }
}

extension MenuBarDriver.Model.Item: Equatable {
  static func ==(
    left: MenuBarDriver.Model.Item,
    right: MenuBarDriver.Model.Item
  ) -> Bool { return
    left.enabled == right.enabled &&
    left.id == right.id &&
    left.title == left.title
  }
}

extension NSMenuItem {
  convenience init(
    title: String,
    action: Selector?,
    target: AnyObject?,
    keyEquivalent: String,
    tag: Int
  ) {
    self.init(title: title, action: action, keyEquivalent: keyEquivalent)
    self.target = target
    self.tag = tag
  }
}
