//
//  ViewController.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import Foundation

class ViewController:
  NSViewController,
  NSCollectionViewDataSource,
  NSCollectionViewDelegateFlowLayout {
  
  struct Model {
    struct Driver {
      let name: String
      let action: String
      let color: NSColor
    }
    struct CauseEffect {
      let cause: String
      let effect: String
    }
    let drivers: [Driver]
    let causesEffects: [CauseEffect]
    let state: String
  }
  
  enum Action {
    case selected(Int)
  }

  @IBOutlet var drivers: NSStackView!
  @IBOutlet var timeline: NSCollectionView!
  var shouldForceRender = false

  var model = Model(
    drivers: [
      Model.Driver(name: "driver 1", action: "event", color: .red),
      Model.Driver(name: "driver 2", action: "event", color: .yellow),
      Model.Driver(name: "driver 3", action: "event", color: .purple),
      Model.Driver(name: "driver 4", action: "event", color: .green)
    ],
    causesEffects: [
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect"),
      Model.CauseEffect(cause: "cause", effect: "effect")
    ],
    state: ""
  ) {
    didSet {
      render(
        old: oldValue,
        new: model
      )
    }
  }
  
  func didReceive(action: Action) {
    
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    shouldForceRender = true
    timeline.enclosingScrollView?.automaticallyAdjustsContentInsets = false
    timeline.postsBoundsChangedNotifications = true
    NotificationCenter.default.addObserver(
      forName: .NSViewBoundsDidChange,
      object: nil,
      queue: .main,
      using: { [weak self] _ in
        if let `self` = self {
          let point = CGPoint(
            x: self.timeline.enclosingScrollView!.documentVisibleRect.origin.x +
              (self.timeline.bounds.width / CGFloat(2.0)) - 44.0 - 10.0,
            y: self.timeline.bounds.height / CGFloat(2)
          )
          if let x = self.timeline.indexPathForItem(at:point)?.item {
            self.didReceive(
              action: .selected(x)
            )
          }
          self.render(
            old: self.model,
            new: self.model
          )
        }
      }
    )
    render(
      old: model,
      new: model
    )
    shouldForceRender = false
  }
  
  override func viewDidLayout() {
    super.viewDidLayout()
    render(
      old: model,
      new: model
    )
  }
  
  func render(old: Model, new: Model) {
    if shouldForceRender || old.drivers != new.drivers {
      drivers.arrangedSubviews.forEach {
        drivers.removeArrangedSubview($0)
      }
      new.drivers
        .flatMap { (x: Model.Driver) -> DriverViewItem? in
          let y = newDriverViewItem()
          y?.set(labelTop: x.name)
          y?.set(labelBottom: x.action)
          y?.set(background: x.color)
          return y
        }
        .forEach {
          drivers.addArrangedSubview($0)
      }
    }
    timeline.enclosingScrollView?.contentInsets = EdgeInsets(
      top: 0,
      left: (view.bounds.size.width - 44.0) / 2.0,
      bottom: 0,
      right: (view.bounds.size.width - 44.0) / 2.0
    )
  }
  
  public func collectionView(
    _ collectionView: NSCollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
      return model.causesEffects.count
  }
  
  func collectionView(
    _ caller: NSCollectionView,
    itemForRepresentedObjectAt path: IndexPath
  ) -> NSCollectionViewItem {
    caller.register(
      NSNib(nibNamed: "TimelineViewItem", bundle: nil),
      forItemWithIdentifier: "TimelineViewItem"
    )
    let x = caller.makeItem(
      withIdentifier: "TimelineViewItem",
      for: path
    )
    return x
  }
  
  func collectionView(
    _ collectionView: NSCollectionView,
    layout collectionViewLayout: NSCollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> NSSize {
    return NSSize(
      width: 60.0,
      height: 138.0
    )
  }

  func newDriverViewItem() -> DriverViewItem? {
    var x = NSArray()
    NSNib(nibNamed: "DriverViewItem", bundle: nil)?.instantiate(
      withOwner: self,
      topLevelObjects: &x
    )
    return x.first { $0 is DriverViewItem } as! DriverViewItem?
  }
}

extension ViewController.Model: Equatable {
  static func ==(left: ViewController.Model, right: ViewController.Model) -> Bool {
    return left.causesEffects == right.causesEffects &&
    left.drivers == right.drivers
  }
}

extension ViewController.Model.CauseEffect: Equatable {
  static func ==(
    left: ViewController.Model.CauseEffect,
    right: ViewController.Model.CauseEffect
  ) -> Bool { return
    left.cause == right.cause &&
    left.effect == right.effect
  }
}

extension ViewController.Model.Driver: Equatable {
  static func ==(
    left: ViewController.Model.Driver,
    right: ViewController.Model.Driver
  ) -> Bool { return
    left.name == right.name &&
    left.action == right.action &&
    left.color == right.color
  }
}
