//
//  ViewController.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import Foundation
import RxSwift

class ViewController:
      NSViewController,
      NSCollectionViewDataSource,
      NSCollectionViewDelegateFlowLayout,
      NSViewControllerProviding {
  
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
    var drivers: [Driver]
    var causesEffects: [CauseEffect]
    var presentedState: String
    var selectedIndex: Int
  }
  
  enum Action {
    case none
    case scrolledToIndex(Int)
  }

  @IBOutlet var drivers: NSStackView?
  @IBOutlet var timeline: NSCollectionView?
  @IBOutlet var presentedState: NSTextView?
  var shouldForceRender = false

  var model = Model(
    drivers: [],
    causesEffects: [],
    presentedState: "",
    selectedIndex: 0
  )
  
  override func viewDidLoad() {
    super.viewDidLoad()
    shouldForceRender = true
    timeline?.enclosingScrollView?.automaticallyAdjustsContentInsets = false
    timeline?.postsBoundsChangedNotifications = true
    NotificationCenter.default.addObserver(
      forName: .NSViewBoundsDidChange,
      object: nil,
      queue: .main,
      using: { [weak self] _ in
        if let `self` = self, let timeline = self.timeline {
          let point = CGPoint(
            x: timeline.enclosingScrollView!.documentVisibleRect.origin.x +
                (self.view.bounds.size.width / 2.0),
            y: timeline.bounds.height / CGFloat(2)
          )
          if let x = timeline.indexPathForItem(at:point)?.item {
            self.output.on(.next(.scrolledToIndex(x)))
          }
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
  
  var root: NSViewController {
    return self
  }
  
  var cleanup = DisposeBag()
  private let output = BehaviorSubject(value: Action.none)

  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input.subscribe {
      if let element = $0.element {
        DispatchQueue.main.async {
          self.render(
            old: self.model,
            new: element
          )
          self.model = element
        }
      }
    }.disposed(by: cleanup)
    return output
  }
  
  func render(old: Model, new: Model) {
    if shouldForceRender || old.drivers != new.drivers {
      drivers?.arrangedSubviews.forEach {
        drivers?.removeArrangedSubview($0)
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
          drivers?.addArrangedSubview($0)
      }
    }
    timeline?.enclosingScrollView?.contentInsets = EdgeInsets(
      top: 0,
      left: (view.bounds.size.width - 44.0) / 2.0,
      bottom: 0,
      right: (view.bounds.size.width - 44.0) / 2.0
    )
    
    if shouldForceRender || new.presentedState != old.presentedState {
      presentedState?.string = new.presentedState
    }
    
    if shouldForceRender || new.causesEffects != old.causesEffects {
      timeline?.reloadData()
    }
    
    if shouldForceRender ||
       new.selectedIndex != old.selectedIndex &&
       new.selectedIndex > 0 {
      if new.causesEffects.count > 0 {
        NSAnimationContext.current().allowsImplicitAnimation = true
        self.timeline?.scrollToItems(
          at: [
            IndexPath(
              item: new.causesEffects.count - 1,
              section: 0
            )
          ],
          scrollPosition: .centeredHorizontally
        )
        NSAnimationContext.current().allowsImplicitAnimation = false
      }
    }
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

extension ViewController {
  static func new(model: ViewController.Model) -> ViewController {
    let x = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "MainViewController") as! ViewController
    x.model = model
    return x
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
