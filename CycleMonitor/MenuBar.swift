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
import Cycle

final class MenuBarDriver: NSObject, Drivable {
  
  struct Model: Equatable {
    struct MenuItem: Equatable {
      let title: String
      let item: Item
    }
    struct Item: Equatable {
      let title: String
      let enabled: Bool
      let id: String
    }
    let items: [Item]
  }
  
  enum Action: Equatable {
    case none
    case didSelectItemWith(id: String)
    case didSelectQuit
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var ids: [Int: String] = [:]
  
  init(model: Model) {
    super.init()
    render(model)
  }
  
  func render(_ input: Model) {
    let new: [NSMenuItem] = input.items.enumerated().map { index, item in
      NSMenuItem(
        title: item.title,
        action: #selector(didReceiveEventFrom(_:)),
        target: self,
        keyEquivalent: "",
        tag: index
      )
    }
    
    ids = input.items.enumerated().reduce([:]) {
      var sum = $0
      sum[$1.offset] = $1.element.id
      return sum
    }
    
    let file = NSMenu(title: "File")
    let item = NSMenuItem()
    item.submenu = file
    new.forEach(file.addItem)
    
    let main = NSMenu(title: "Top")
    main.addItem(
      NSMenuItem.mainWith(
        items: [
          quit()
        ]
      )
    )
    main.addItem(item)
    NSApplication.shared.mainMenu = main
  }
    
  func events() -> Observable<MenuBarDriver.Action> {
    output.asObservable()
  }
  
  func quit() -> NSMenuItem {
    NSMenuItem(
      title: "Quit Cycle Monitor",
      action: #selector(didReceiveEventFromQuit(_:)),
      target: self,
      keyEquivalent: "",
      tag: 999
    )
  }
  
  @objc func didReceiveEventFrom(_ menu: NSMenuItem) {
      ids[menu.tag]
        >>- Action.didSelectItemWith
        >>- RxSwift.Event.next
        >>- output.on
  }

  @objc func didReceiveEventFromQuit(_ menu: NSMenuItem) {
    output.on(.next(.didSelectQuit))
  }
}

extension NSMenuItem {
  static func mainWith(items: [NSMenuItem]) -> NSMenuItem {
    let appMenu = NSMenu(title: "")
    let parent = NSMenuItem()
    parent.submenu = appMenu
    items.forEach(appMenu.addItem)
    return parent
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
