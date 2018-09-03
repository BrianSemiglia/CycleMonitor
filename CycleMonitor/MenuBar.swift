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
    case didSelectQuit
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var ids: [Int: String] = [:]
  
  init(model: Model) {
    render(model)
  }
  
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input
      .observeOn(MainScheduler.instance)
      .distinctUntilChanged()
      .subscribe(onNext: render)
      .disposed(by: cleanup)
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
  
  func quit() -> NSMenuItem { return
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
