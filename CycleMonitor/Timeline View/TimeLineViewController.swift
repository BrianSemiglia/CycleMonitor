//
//  TimeLineViewController.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import Foundation
import RxSwift
import RxCocoa
import Curry
import Runes

class TimeLineViewController:
      NSViewController,
      NSCollectionViewDataSource,
      NSCollectionViewDelegateFlowLayout,
      NSViewControllerProviding,
      NSTextViewDelegate {
  
  struct Model {
    struct Driver {
      let label: String
      let action: String?
      let background: NSColor
      let side: NSColor
    }
    struct CauseEffect {
      var cause: String
      var effect: String
      var approved: Bool
      var color: NSColor
      init(cause: String, effect: String, approved: Bool = false, color: NSColor) {
        self.cause = cause
        self.effect = effect
        self.approved = approved
        self.color = color
      }
    }
    enum Connection {
      case idle
      case connecting
      case connected
      case disconnected
    }
    struct Selection {
      var color: NSColor
      let index: Int
    }
    enum EventHandlingState: Int {
      case playing
      case playingSendingEvents
      case playingSendingEffects
      case recording
    }
    var drivers: [Driver]
    var causesEffects: [CauseEffect]
    var presentedState: String
    var selected: Selection?
    var connection: Connection
    var eventHandlingState: EventHandlingState
    var isDisplayingSave: Bool
  }
  
  enum Action {
    case none
    case scrolledToIndex(Int)
    case toggledApproval(Int, Bool)
    case didSelectEventHandling(Model.EventHandlingState)
    case didCommitPendingStateEdit(String)
    case didCreatePendingStateEdit(String)
  }

  @IBOutlet var drivers: NSStackView?
  @IBOutlet var timeline: NSCollectionView?
  @IBOutlet var presentedState: NSTextView?
  @IBOutlet var connection: NSProgressIndicator?
  @IBOutlet var disconnected: NSTextField?
  @IBOutlet var eventHandling: NSSegmentedControl?
  @IBOutlet var state: NSTextView?
  @IBOutlet var save: NSButton?

  private var cleanup = DisposeBag()
  private let output = BehaviorSubject(value: Action.none)
  private var shouldForceRender = false

  var model = Model(
    drivers: [],
    causesEffects: [],
    presentedState: "",
    selected: nil,
    connection: .disconnected,
    eventHandlingState: .playing,
    isDisplayingSave: false
  )
  
  override func viewDidLoad() {
    super.viewDidLoad()
    shouldForceRender = true

    eventHandling?.segmentCount = 4
    eventHandling?.setLabel(
      "Review",
      forSegment: 0
    )
    eventHandling?.setWidth(
      CGFloat(("Review".characters.count * 7) + 14),
      forSegment: 0
    )
    eventHandling?.setLabel(
      "Events On Device",
      forSegment: 1
    )
    eventHandling?.setWidth(
      CGFloat(("Events On Device".characters.count * 7) + 14),
      forSegment: 1
    )
    eventHandling?.setLabel(
      "Effects On Device",
      forSegment: 2
    )
    eventHandling?.setWidth(
      CGFloat(("Effects On Device".characters.count * 7) + 14),
      forSegment: 2
    )
    eventHandling?.setLabel(
      "Record",
      forSegment: 3
    )
    eventHandling?.setWidth(
      CGFloat(("Record".characters.count * 7) + 14),
      forSegment: 3
    )
    eventHandling?.action = #selector(
      didReceiveEventFromEventHandling(_:)
    )

    state?.isAutomaticQuoteSubstitutionEnabled = false
    state?.isAutomaticDashSubstitutionEnabled = false
    state?.isAutomaticTextReplacementEnabled = false
    state?.delegate = self
    
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
            self.output.on(
              .next(
                .scrolledToIndex(x)
              )
            )
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
  
  func textDidChange(_ notification: Notification) {
    if let x = presentedState?.string {
      output.on(
        .next(
          .didCreatePendingStateEdit(
            x
          )
        )
      )
    }
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
  
  @IBAction func didReceiveEventFromStateUpdate(_ input: NSButton) {
    output.on(
      .next(
        .didCommitPendingStateEdit(
          state!.string!
        )
      )
    )
  }
  
  @IBAction func didReceiveEventFromEventHandling(_ input: NSSegmentedControl) {
    if let new = input.selectedSegment.eventHandlingState {
      output.on(.next(.didSelectEventHandling(new)))
    }
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
          y?.set(background: x.background)
          y?.set(side: x.side)
          return y
        }
        .forEach {
          drivers?.addArrangedSubview($0)
      }
    }
    
    eventHandling?.selectedSegment = new.eventHandlingState.rawValue
    timeline?.enclosingScrollView?.horizontalScroller?.isHidden = true
    
    if shouldForceRender || new.presentedState != presentedState?.string {
      /* convert strings to arrays and diff them. replace one character at a time. maintains cursor? */
      presentedState?.string = new.presentedState
    }
    
    if shouldForceRender || new.causesEffects.count != old.causesEffects.count {
      timeline?.reloadData()
    }
    
    let pathsCells = timeline?.indexPathsForVisibleItems().flatMap { x -> (IndexPath, TimelineViewItem)? in
      timeline
        .flatMap { $0.item(at: x) }
        .flatMap { $0 as? TimelineViewItem }
        .map { (x, $0) }
    }
    
    pathsCells?.forEach { path, cell in
      let x = TimeLineViewController.modelFrom(
        model: self.model,
        cell: cell,
        path: path,
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
      cell.model = x
    }
    
    if new.eventHandlingState == .recording,
      new.causesEffects != old.causesEffects,
      new.causesEffects.count > 0,
      let newIndex = new.selected?.index {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { // <-- async hack
          NSAnimationContext.current().allowsImplicitAnimation = true
          self.timeline?.scrollToItems(
            at: [
              IndexPath(
                item: newIndex,
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
      case .idle:
        break
      }
    }
    
    NSAnimationContext.runAnimationGroup({ group in
      self.save?.isHidden = new.isDisplayingSave == false
    })
    
  }
  
  static func modelFrom(
    model: Model,
    cell: TimelineViewItem,
    path: IndexPath,
    selection: @escaping (Bool) -> Void
  ) -> TimelineViewItem.Model { return
    TimelineViewItem.Model(
      background: model.selected
        .flatMap { $0.index == path.item ? $0 : nil }
        .map { $0.color }
        ?? .white,
      top: model.causesEffects[path.item].color,
      bottom: .blue,
      selected: model.causesEffects[path.item].approved,
      selection: selection
    )
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
      NSNib(
        nibNamed: "TimelineViewItem",
        bundle: nil
      ),
      forItemWithIdentifier: "TimelineViewItem"
    )
    let x = caller.makeItem(
      withIdentifier: "TimelineViewItem",
      for: path
    ) as! TimelineViewItem
    x.model = TimeLineViewController.modelFrom(
      model: model,
      cell: x,
      path: path,
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
      width: 42.0,
      height: 74.0
    )
  }
}

extension TimeLineViewController {
  static func new(model: TimeLineViewController.Model) -> TimeLineViewController {
    let x = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "TimeLineViewController") as! TimeLineViewController
    x.model = model
    return x
  }
}

extension TimeLineViewController.Model: Equatable {
  static func ==(
    left: TimeLineViewController.Model,
    right: TimeLineViewController.Model
  ) -> Bool { return
    left.drivers == right.drivers &&
    left.causesEffects == right.causesEffects &&
    left.presentedState == right.presentedState &&
    left.selected == left.selected &&
    left.connection == right.connection &&
    left.eventHandlingState == right.eventHandlingState &&
    left.isDisplayingSave == right.isDisplayingSave
  }
}

extension TimeLineViewController.Action: Equatable {
  static func ==(left: TimeLineViewController.Action, right: TimeLineViewController.Action) -> Bool {
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

extension TimeLineViewController.Model.CauseEffect: Equatable {
  static func ==(
    left: TimeLineViewController.Model.CauseEffect,
    right: TimeLineViewController.Model.CauseEffect
  ) -> Bool { return
    left.cause == right.cause &&
    left.effect == right.effect &&
    left.approved == right.approved
  }
}

extension TimeLineViewController.Model.Driver: Equatable {
  static func ==(
    left: TimeLineViewController.Model.Driver,
    right: TimeLineViewController.Model.Driver
  ) -> Bool { return
    left.label == right.label &&
    left.action == right.action &&
    left.background == right.background &&
    left.side == right.side
  }
}

extension TimeLineViewController.Model.Connection: Equatable {
  static func ==(
    left: TimeLineViewController.Model.Connection,
    right: TimeLineViewController.Model.Connection
  ) -> Bool {
    switch (left, right) {
    case (.connecting, .connecting): return true
    case (.connected, connected): return true
    case (.disconnected, disconnected): return true
    default: return false
    }
  }
}

extension TimeLineViewController.Model.Selection: Equatable {
  static func ==(
    left: TimeLineViewController.Model.Selection,
    right: TimeLineViewController.Model.Selection
  ) -> Bool { return
    left.color == right.color &&
    left.index == right.index
  }
}

extension NSScrollView {
    var documentVisibleCenter: NSPoint { return
        NSPoint(
            x: documentVisibleRect.origin.x + (bounds.size.width / 2.0),
            y: bounds.height / CGFloat(2)
        )
    }
}

extension Int {
  var eventHandlingState: TimeLineViewController.Model.EventHandlingState? {
    switch self {
    case 0: return .playing
    case 1: return .playingSendingEvents
    case 2: return .playingSendingEffects
    case 3: return .recording
    default: return nil
    }
  }
}
