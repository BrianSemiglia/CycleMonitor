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
      let label: String
      let action: String?
      let color: NSColor
    }
    struct CauseEffect {
      var cause: String
      var effect: String
      var approved: Bool
      init(cause: String, effect: String, approved: Bool = false) {
        self.cause = cause
        self.effect = effect
        self.approved = approved
      }
    }
    enum Connection {
      case connecting
      case connected
      case disconnected
    }
    struct Selection {
      var color: NSColor
      let index: Int
    }
    var drivers: [Driver]
    var causesEffects: [CauseEffect]
    var presentedState: String
    var selected: Selection?
    var focused: Int?
    var connection: Connection
  }
  
  enum Action {
    case none
    case scrolledToIndex(Int)
    case toggledApproval(Int, Bool)
  }

  @IBOutlet var drivers: NSStackView?
  @IBOutlet var timeline: NSCollectionView?
  @IBOutlet var presentedState: NSTextView?
  @IBOutlet var connection: NSProgressIndicator?
  @IBOutlet var disconnected: NSTextField?
  
  private var cleanup = DisposeBag()
  private let output = BehaviorSubject(value: Action.none)
  private var shouldForceRender = false

  var model = Model(
    drivers: [],
    causesEffects: [],
    presentedState: "",
    selected: nil,
    focused: 0,
    connection: .disconnected
  )
  
  override func viewDidLoad() {
    super.viewDidLoad()
    shouldForceRender = true
    timeline?.enclosingScrollView?.horizontalScroller?.isHidden = true
    timeline?.enclosingScrollView?.automaticallyAdjustsContentInsets = false
    timeline?.postsBoundsChangedNotifications = true
    NotificationCenter.default.addObserver(
      forName: .NSViewBoundsDidChange,
      object: nil,
      queue: .main,
      using: { [weak self] _ in
        if let `self` = self, let timeline = self.timeline {
          let point = timeline.enclosingScrollView!.documentVisibleCenter
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
    if shouldForceRender || old.drivers != new.drivers {
      drivers?.arrangedSubviews.forEach {
        $0.removeFromSuperview()
      }
      new.drivers
        .flatMap { (x: Model.Driver) -> DriverViewItem? in
          let y = newDriverViewItem()
          y?.set(labelTop: x.label)
          y?.set(labelBottom: x.action ?? "")
          y?.set(background: x.color)
          return y
        }
        .forEach {
          drivers?.addArrangedSubview($0)
      }
    }
    
    timeline?.enclosingScrollView?.horizontalScroller?.isHidden = true
    
    if shouldForceRender || new.presentedState != old.presentedState {
      presentedState?.string = new.presentedState
    }
    
    if shouldForceRender || new.causesEffects != old.causesEffects {
      timeline?.reloadData()
    }
    
    if
      let new = new.selected,
      old.selected != new,
      let timeline = timeline
    {
      timeline.reloadItems(
        at: timeline.indexPathsForVisibleItems()
      )
    }
    
    if let focused = new.focused,
      focused != old.focused,
      focused > 0,
      new.selected.map({ $0.index != new.focused }) == true
    {
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
    
    if shouldForceRender || new.connection != old.connection {
      switch new.connection {
      case .connecting:
        connection?.startAnimation(self)
        disconnected?.isHidden = true
      case .connected:
        connection?.stopAnimation(self)
        disconnected?.isHidden = true
      case .disconnected:
        connection?.stopAnimation(true)
        disconnected?.isHidden = false
      }
    }
  }
  
  func collectionView(
    _ collectionView: NSCollectionView,
    didSelectItemsAt indexPaths: Set<IndexPath>
  ) {
    if let index = indexPaths.first?.item {
      output.on(
        .next(
          .scrolledToIndex(index)
        )
      )
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
    ) as! TimelineViewItem
    x.model = TimelineViewItem.Model(
      color: model.selected
        .flatMap { $0.index == path.item ? $0 : nil }
        .map { $0.color }
        ?? .white,
      selected: model.causesEffects[path.item].approved,
      selection: { [weak self] isSelected in
        self?.output.on(
          .next(
            .toggledApproval(
              path.item,
              isSelected
            )
          )
        )
      }
    )
    return x
  }
  
  func collectionView(
    _ collectionView: NSCollectionView,
    layout collectionViewLayout: NSCollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> NSSize {
    return cell
  }
  
  func collectionView(
    _ collectionView: NSCollectionView,
    layout collectionViewLayout: NSCollectionViewLayout,
    insetForSectionAt section: Int
  ) -> EdgeInsets {
    return EdgeInsets(
      top: 0,
      left: (view.bounds.size.width - cell.width) / 2.0,
      bottom: 0,
      right: (view.bounds.size.width - cell.width) / 2.0
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
  
  var cell: NSSize { return
    NSSize(
      width: 44.0,
      height: 118.0
    )
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
    left.drivers == right.drivers &&
    left.connection == right.connection &&
    left.focused == right.focused &&
    left.presentedState == right.presentedState &&
    left.selected == left.selected
  }
}

extension ViewController.Action: Equatable {
  static func ==(left: ViewController.Action, right: ViewController.Action) -> Bool {
    switch (left, right) {
    case (.none, .none):
      return true
    case (scrolledToIndex(let a), scrolledToIndex(let b)):
      return a == b
    case (.toggledApproval(let a, let c), .toggledApproval(let b, let d)):
      return a == b && c == d
    default:
      return false
    }
  }
}

extension ViewController.Model.CauseEffect: Equatable {
  static func ==(
    left: ViewController.Model.CauseEffect,
    right: ViewController.Model.CauseEffect
  ) -> Bool { return
    left.cause == right.cause &&
    left.effect == right.effect &&
    left.approved == right.approved
  }
}

extension ViewController.Model.Driver: Equatable {
  static func ==(
    left: ViewController.Model.Driver,
    right: ViewController.Model.Driver
  ) -> Bool { return
    left.label == right.label &&
    left.action == right.action &&
    left.color == right.color
  }
}

extension ViewController.Model.Connection: Equatable {
  static func ==(
    left: ViewController.Model.Connection,
    right: ViewController.Model.Connection
  ) -> Bool {
    switch (left, right) {
    case (.connecting, .connecting): return true
    case (.connected, connected): return true
    case (.disconnected, disconnected): return true
    default: return false
    }
  }
}

extension ViewController.Model.Selection: Equatable {
  static func ==(
    left: ViewController.Model.Selection,
    right: ViewController.Model.Selection
  ) -> Bool { return
    left.color == right.color &&
    left.index == right.index
  }
}

extension NSScrollView {
    var documentVisibleCenter: NSPoint { return
        CGPoint(
            x: documentVisibleRect.origin.x + (bounds.size.width / 2.0),
            y: bounds.height / CGFloat(2)
        )
    }
}
