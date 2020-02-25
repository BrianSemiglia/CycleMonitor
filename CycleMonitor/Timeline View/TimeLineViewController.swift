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
import Cycle

final class TimeLineViewController:
      NSViewController,
      NSCollectionViewDataSource,
      NSCollectionViewDelegateFlowLayout,
      NSTextViewDelegate,
      Drivable {
  
  struct Model: Equatable {
    struct Driver: Equatable, Identifiable {
      let label: String
      let action: String?
      let background: NSColor
      let side: NSColor
      let id: AnyHashable
    }
    struct CauseEffect: Equatable, Identifiable {
      var cause: String
      var effect: String
      var approved: Bool
      var color: NSColor
      var id: AnyHashable
      init(cause: String, effect: String, approved: Bool = false, color: NSColor, id: AnyHashable) {
        self.cause = cause
        self.effect = effect
        self.approved = approved
        self.color = color
        self.id = id
      }
    }
    enum Connection: Equatable {
      case idle
      case connecting
      case connected
      case disconnected
    }
    struct Selection: Equatable {
      var color: NSColor
      let index: Int
    }
    enum EventHandlingState: Int, Equatable {
      case playing
      case playingSendingEvents
      case playingSendingEffects
      case recording
    }
    struct Device: Equatable, Identifiable {
        var name: String
        var connection: Connection
        var id: AnyHashable
    }
    var drivers: [Driver]
    var causesEffects: [CauseEffect]
    var presentedState: NSAttributedString
    var selected: Selection?
    var connection: Connection
    var eventHandlingState: EventHandlingState
    var devices: [Device]
    var indexOfSelectedDevice: Int
  }
  
  enum Action: Equatable {
    case none
    case scrolledToIndex(Int)
    case toggledApproval(Int, Bool)
    case didSelectEventHandling(Model.EventHandlingState)
    case didCreatePendingStateEdit(String)
    case didSelectClearAll
    case didSelectItemWith(id: String)
  }

  @IBOutlet var drivers: NSStackView?
  @IBOutlet var timeline: NSCollectionView?
    @IBOutlet var presentedState: NSTextView? {
        didSet {
            self.presentedState?.font = NSFont(
                descriptor: NSFontDescriptor(
                    name: "Courier",
                    size: 14.0
                ),
                size: 14.0
            )
        }
    }
  @IBOutlet var connection: NSProgressIndicator?
  @IBOutlet var disconnected: NSTextField?
  @IBOutlet var eventHandling: NSSegmentedControl?
  @IBOutlet var state: NSTextView?
  @IBOutlet var clearAll: NSButton?
  @IBOutlet var devices: NSPopUpButton?

  private var cleanup = DisposeBag()
  public  let output = BehaviorSubject(value: Action.none)
  private var shouldForceRender = false

  var model = Model(
    drivers: [],
    causesEffects: [],
    presentedState: NSAttributedString(string: ""),
    selected: nil,
    connection: .disconnected,
    eventHandlingState: .playing,
    devices: [],
    indexOfSelectedDevice: 0
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
      CGFloat(("Review".count * 7) + 14),
      forSegment: 0
    )
    eventHandling?.setLabel(
      "Events On Device",
      forSegment: 1
    )
    eventHandling?.setWidth(
      CGFloat(("Events On Device".count * 7) + 14),
      forSegment: 1
    )
    eventHandling?.setLabel(
      "Effects On Device",
      forSegment: 2
    )
    eventHandling?.setWidth(
      CGFloat(("Effects On Device".count * 7) + 14),
      forSegment: 2
    )
    eventHandling?.setLabel(
      "Record",
      forSegment: 3
    )
    eventHandling?.setWidth(
      CGFloat(("Record".count * 7) + 14),
      forSegment: 3
    )
    eventHandling?.action = #selector(
      didReceiveEventFromEventHandling(_:)
    )

    state?.isAutomaticQuoteSubstitutionEnabled = false
    state?.isAutomaticDashSubstitutionEnabled = false
    state?.isAutomaticTextReplacementEnabled = false
    state?.delegate = self
    
    timeline?.enclosingScrollView?.horizontalScroller?.alphaValue = 0
    timeline?.enclosingScrollView?.automaticallyAdjustsContentInsets = false
    timeline?.postsBoundsChangedNotifications = true

    NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
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
    
    clearAll?
      .rx
      .tap
      .subscribe(onNext: { [weak self] in
        self?.output.on(
          .next(
            .didSelectClearAll
          )
        )
      })
      .disposed(by: cleanup)
    
    devices?.target = self
    devices?.action = #selector(didReceiveEventFromDevices(_:))
    
    render(
      old: model,
      new: model
    )
    shouldForceRender = false
  }
  
  @objc func didReceiveEventFromDevices(_ button: NSPopUpButton) {
    output.on(
      .next(
        .didSelectItemWith(
          id: button.title
        )
      )
    )
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

    public func rendered(_ input: Model) {
        let old = self.model
        self.model = input
        self.render(
          old: old,
          new: input
        )
    }
    
    public func render(_ input: Model) {
        let old = self.model
        self.model = input
        self.render(
            old: old,
            new: self.model
        )
    }
    
    func events() -> Observable<TimeLineViewController.Action> {
        output.asObservable()
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
      new
        .drivers
        .compactMap { (x: Model.Driver) -> DriverViewItem? in
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
    
    if shouldForceRender || new.presentedState != presentedState?.attributedString() {
      /* convert strings to arrays and diff them. replace one character at a time. maintains cursor? */
        presentedState?.textStorage?.setAttributedString(new.presentedState)
    }
    
    if shouldForceRender || new.causesEffects.count != old.causesEffects.count {
      timeline?.reloadData()
    }
    
    let pathsCells = timeline?.indexPathsForVisibleItems().compactMap { x -> (IndexPath, TimelineViewItem)? in
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
    
    if new.devices != old.devices {
      devices?.removeAllItems()
      devices?.addItem(
        withTitle: "None"
      )
      new.devices.forEach {
        devices?.addItem(
          withTitle: $0.name
        )
      }
      let selected = new
        .devices
        .first(where: { $0.connection == .connecting || $0.connection == .connected })
        .map { $0.name }
      
      if let selected = selected {
        devices?.selectItem(withTitle: selected)
      }
    }
    
    if new.eventHandlingState == .recording,
      new.causesEffects != old.causesEffects,
      new.causesEffects.count > 0,
      let newIndex = new.selected?.index {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { // <-- async hack
          NSAnimationContext.current.allowsImplicitAnimation = true
          self.timeline?.scrollToItems(
            at: [
              IndexPath(
                item: newIndex,
                section: 0
              )
            ],
            scrollPosition: NSCollectionView.ScrollPosition.centeredHorizontally
          )
          NSAnimationContext.current.allowsImplicitAnimation = false
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
  }
  
  static func modelFrom(
    model: Model,
    cell: TimelineViewItem,
    path: IndexPath,
    selection: @escaping (Bool) -> Void
  ) -> TimelineViewItem.Model {
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
      model.causesEffects.count
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
      forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TimelineViewItem")
    )
    let x = caller.makeItem(
      withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TimelineViewItem"),
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
    cell
  }
  
  func collectionView(
    _ collectionView: NSCollectionView,
    layout collectionViewLayout: NSCollectionViewLayout,
    insetForSectionAt section: Int
  ) -> NSEdgeInsets {
    return NSEdgeInsets(
      top: 0,
      left: (view.bounds.size.width - cell.width) / 2.0,
      bottom: 0,
      right: (view.bounds.size.width - cell.width) / 2.0
    )
  }

  func newDriverViewItem() -> DriverViewItem? {
    var x = Optional.some(NSArray())
    NSNib(nibNamed: "DriverViewItem", bundle: nil)?.instantiate(
      withOwner: self,
      topLevelObjects: &x
    )
    return x?.first { $0 is DriverViewItem } as! DriverViewItem?
  }
  
  var cell: NSSize {
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

extension NSScrollView {
    var documentVisibleCenter: NSPoint {
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

extension TimeLineViewController.Model.EventHandlingState {
  var index: Int {
    switch self {
    case .playing: return 0
    case .playingSendingEvents: return 1
    case .playingSendingEffects: return 2
    case .recording: return 3
    }
  }
}

extension TimeLineViewController.Model {
    static var empty = TimeLineViewController.Model(
        drivers: [],
        causesEffects: [],
        presentedState: NSAttributedString(string: ""),
        selected: nil,
        connection: .connected,
        eventHandlingState: .playing,
        devices: [],
        indexOfSelectedDevice: 0
    )
}
