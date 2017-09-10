//
//  Cycle-MacOS.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import RxSwift
import RxOptional

class AppDelegateStub: NSObject, NSApplicationDelegate {
  struct Model {}
  enum Action {
    case none
  }
  private let output = BehaviorSubject(value: Action.none)
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    return output
  }
}

struct CycleMonitorApp: SinkSourceConverting {
  struct Model: Initializable {
    enum EventHandlingState {
      case playing
      case playingSendingEvents
      case playingSendingEffects
      case recording
    }
    struct TimeLineView {
      var selectedIndex: Int?
    }
    enum Connection {
      case idle
      case disconnected
      case connecting
      case connected
    }
    var events: [Event] = []
    var timeLineView = TimeLineView(
      selectedIndex: nil
    )
    var multipeer = Connection.idle
    var application = AppDelegateStub.Model()
    var browser = BrowserDriver.Model(state: .idle)
    var menuBar = MenuBarDriver.Model(
      items: [
        MenuBarDriver.Model.Item.openTimeline,
        MenuBarDriver.Model.Item.saveTimeline,
        MenuBarDriver.Model.Item.exportTests
      ]
    )
    var eventHandlingState = EventHandlingState.playing
    var isTerminating = false
  }
  struct Drivers: NSApplicationDelegateProviding, ScreenDrivable {
    let screen: TimeLineViewController
    let multipeer: MultipeerJSON
    let application: AppDelegateStub
    let browser: BrowserDriver
    let menuBar: MenuBarDriver
    let termination: TerminationDriver
  }
  func driversFrom(initial: CycleMonitorApp.Model) -> CycleMonitorApp.Drivers { return
    Drivers(
      screen: TimeLineViewController.new(
        model: initial.coerced()
      ),
      multipeer: MultipeerJSON(),
      application: AppDelegateStub(),
      browser: BrowserDriver(
        initial: initial.browser
      ),
      menuBar: MenuBarDriver(
        model: initial.menuBar
      ),
      termination: TerminationDriver(
        model: TerminationDriver.Model(
          shouldTerminate: initial.isTerminating
        )
      )
    )
  }
  func effectsFrom(
    events: Observable<Model>,
    drivers: Drivers
  ) -> Observable<Model> {
    let screen = drivers
      .screen
      .rendered(events.map (TimeLineViewController.Model.coerced))
      .tupledWithLatestFrom(events)
      .reduced()
    
    let application = drivers
      .application
      .rendered(events.map { $0.application })
      .tupledWithLatestFrom(events)
      .reduced()

    let multipeer = drivers.multipeer
      .rendered(
        .merge([
          events.jsonEvents,
          events.jsonEffects
        ])
      )
      .tupledWithLatestFrom(events)
      .reduced()
    
    let browser = drivers
      .browser
      .rendered(events.map { $0.browser })
      .tupledWithLatestFrom(events)
      .reduced()
    
    let menuBar = drivers
      .menuBar
      .rendered(events.map { $0.menuBar })
      .tupledWithLatestFrom(events)
      .reduced()
    
    let termination = drivers
      .termination
      .rendered(
        events.map {
          TerminationDriver.Model(
            shouldTerminate: $0.isTerminating
          )
        }
      )
      .tupledWithLatestFrom(events)
      .map { $0.1 }
    
    return .merge([
      screen,
      application,
      multipeer,
      browser,
      menuBar,
      termination
    ])
  }
}

extension CycleMonitorApp.Model {
  var selectedEvent: [AnyHashable: Any] { return
    [
      "cause": [
        "id": events[timeLineView.selectedIndex!].cause.id,
        "action": events[timeLineView.selectedIndex!].cause.action
      ]
    ]
  }
  var selectedEffectDraft: [AnyHashable: Any]? { return
    events[timeLineView.selectedIndex!].pendingEffectEdit.map { ["effect": $0] }
  }
  var selectedEffect: [AnyHashable: Any] { return [
    "effect": events[timeLineView.selectedIndex!].effect
  ]}
}

extension Observable where E == CycleMonitorApp.Model {
  var jsonEvents: Observable<[AnyHashable: Any]> { return
    distinctUntilChanged { x, y in
      !(y.eventHandlingState == .playingSendingEvents &&
        x.timeLineView.selectedIndex != y.timeLineView.selectedIndex)
    }
    .filter { $0.events.count > 0 }
    .map { $0.selectedEvent }
  }
  
  var jsonEffects: Observable<[AnyHashable: Any]> { return
    distinctUntilChanged { x, y in
      !(y.eventHandlingState == .playingSendingEffects &&
        x.timeLineView.selectedIndex != y.timeLineView.selectedIndex)
    }
    .filter { $0.events.count > 0 }
    .map {
      $0.selectedEffectDraft ??
      $0.selectedEffect
    }
  }
}

extension Data {
  // TODO: Convert to result type
  var JSON: [AnyHashable: Any]? { return
    (
      try? JSONSerialization.jsonObject(
        with: self,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      )
    )
    .flatMap { $0 as? [AnyHashable: Any] }
  }
}

extension CycleMonitorApp.Model.EventHandlingState {
  var timeLineEventHandlingState: TimeLineViewController.Model.EventHandlingState {
    switch self {
    case .playing: return .playing
    case .playingSendingEvents: return .playingSendingEvents
    case .playingSendingEffects: return .playingSendingEffects
    case .recording: return .recording
    }
  }
}

extension Event.Driver {
  static func coerced(_ x: Event.Driver) -> TimeLineViewController.Model.Driver {
    return x.coerced()
  }
}

extension Event.Driver {
    func coerced() -> TimeLineViewController.Model.Driver { return
        TimeLineViewController.Model.Driver(
            label: label,
            action: action,
            background: id.hashValue.goldenRatioColored(),
            side: id.hashValue.goldenRatioColored(
                brightness: action.characters.count == 0 ? 0.95 : 0.5
            )
        )
    }
}

extension TimeLineViewController.Model.CauseEffect {
  static func coerced(_ x: Event) -> TimeLineViewController.Model.CauseEffect {
    return x.coerced()
  }
}

extension Event {
  func coerced() -> TimeLineViewController.Model.CauseEffect { return
    TimeLineViewController.Model.CauseEffect(
      cause: cause.action,
      effect: effect,
      approved: isApproved,
      color: cause.id.hashValue.goldenRatioColored()
    )
  }
}

extension TimeLineViewController.Model {
  static func coerced(_ x: CycleMonitorApp.Model) -> TimeLineViewController.Model {
    return x.coerced()
  }
}

extension CycleMonitorApp.Model {
  func coerced() -> TimeLineViewController.Model { return
    TimeLineViewController.Model(
      drivers: events[safe: timeLineView.selectedIndex ?? 0]
        .map { $0.drivers.map (Event.Driver.coerced) }
        ?? []
      ,
      causesEffects: events.map (TimeLineViewController.Model.CauseEffect.coerced),
      presentedState: events[safe: timeLineView.selectedIndex ?? 0]
        .map { $0.pendingEffectEdit ?? $0.effect }
        ?? ""
      ,
      selected: TimeLineViewController.Model.Selection(
        color: .cy_lightGray,
        index: timeLineView.selectedIndex ?? 0
      ),
      connection: multipeer.timeLineViewControllerConnection,
      eventHandlingState: eventHandlingState.timeLineEventHandlingState,
      isDisplayingSave: events[safe: timeLineView.selectedIndex ?? 0]
        .flatMap { curry(!=) <^> $0.pendingEffectEdit <*> $0.effect }
        ?? false
    )
  }
}

extension Array {
  subscript (safe index: Int) -> Element? {
    return index < count ? self[index] : nil
  }
}

extension CycleMonitorApp.Model.Connection {
  var timeLineViewControllerConnection: TimeLineViewController.Model.Connection {
    switch self {
    case .idle: return .idle
    case .connecting: return .connecting
    case .connected: return .connected
    case .disconnected: return .disconnected
    }
  }
}

extension NSColor {
  static var cy_lightGray: NSColor { return
    NSColor(
      red: 232.0/255.0,
      green: 232.0/255.0,
      blue: 232.0/255.0,
      alpha: 1
    )
  }
}

extension ObservableType {
  func tupledWithLatestFrom<T>(_ input: Observable<T>) -> Observable<(E, T)> { return
    withLatestFrom(input) { ($0.0, $0.1 ) }
  }
}

extension ObservableType where E == (TimeLineViewController.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .scrolledToIndex(let index):
        var new = context
        new.timeLineView.selectedIndex = index
        return new
      case .toggledApproval(let index, let isApproved):
        var new = context
        new.events[index].isApproved = isApproved
        return new
      case .didSelectEventHandling(let new):
        switch new {
        case .playing:
          var new = context
          new.eventHandlingState = .playing
          return new
        case .playingSendingEvents:
          var new = context
          new.eventHandlingState = .playingSendingEvents
          return new
        case .playingSendingEffects:
          var new = context
          new.eventHandlingState = .playingSendingEffects
          return new
        case .recording:
          var new = context
          new.eventHandlingState = .recording
          return new
        }
      case .didCommitPendingStateEdit(let newState):
        var new = context
        new.events[new.timeLineView.selectedIndex!].effect = newState
        new.events[new.timeLineView.selectedIndex!].pendingEffectEdit = nil
        return new
      case .didCreatePendingStateEdit(let newState):
        var new = context
        new.events[new.timeLineView.selectedIndex!].pendingEffectEdit = newState
        return new
      default:
        return context
      }
    }
  }
}

extension ObservableType where E == (MultipeerJSON.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .received(let data) where context.eventHandlingState == .recording:
        var new = context
        new.events += data
          .JSON
          .flatMap(Argo.decode)
          .map { [$0] }
          ?? []
        new.timeLineView.selectedIndex = new.events.count > 0
          ? new.events.count - 1
          : nil
        return new
      case .connected:
        var new = context
        new.multipeer = .connected
        return new
      case .connecting:
        var new = context
        new.multipeer = .connecting
        return new
      case .disconnected:
        var new = context
        new.multipeer = .disconnected
        return new
      default:
        return context
      }
    }
  }
}

extension ObservableType where E == (AppDelegateStub.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      return context
    }
  }
}

extension Event {
  static func eventsFrom(_ input: [AnyHashable: Any]) -> [Event] { return
    input["events"]
      .flatMap { $0 as? [[AnyHashable: Any]] }
      .flatMap { $0.flatMap(Argo.decode) }
      ?? []
  }
}

extension ObservableType where E == (BrowserDriver.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .didOpen(let json):
        var new = context
        new.events = Event.eventsFrom(json)
        new.timeLineView.selectedIndex = json["selectedIndex"].flatMap(decode)
        new.browser.state = .idle
        return new
      case .cancelling, .none:
        var new = context
        new.browser.state = .idle
        return new
      default:
        return context
      }
    }
  }
}

extension ObservableType where E == (MenuBarDriver.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .didSelectItemWith(id: let id) where id == MenuBarDriver.Model.Item.openTimelineID:
        var new = context
        new.browser.state = .opening
        return new
      case .didSelectItemWith(id: let id) where id == MenuBarDriver.Model.Item.saveTimelineID:
        var new = context
        new.browser.state = .saving(
          context.saveFile
        )
        return new
      case .didSelectItemWith(id: let id) where id == MenuBarDriver.Model.Item.exportTestsID:
        var new = context
        new.browser.state = .savingMany(
          context
            .events
            .filter { $0.isApproved }
            .map { $0.testFile }
        )
        return new
      case .didSelectQuit:
        var new = context
        new.isTerminating = true
        return new
      default:
        break
      }
      return context
    }
  }
}

class TerminationDriver {
  struct Model: Equatable {
    var shouldTerminate: Bool
    static func ==(left: Model, right: Model) -> Bool { return
      left.shouldTerminate == right.shouldTerminate
    }
  }
  
  enum Action {
    case none
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)

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
    input
      .observeOn(MainScheduler.instance)
      .distinctUntilChanged()
      .subscribe(onNext: render)
      .disposed(by: cleanup)
    return output
  }
  
  func render(_ input: Model) {
    if input.shouldTerminate {
      NSApplication
        .shared()
        .terminate(nil)
    }
  }
}

/*
 Monitor, Driver, Caller
 Model,   JSON,   Model
 
           [Cocoa, Cycle-Mac]  [Cocoa]
 [Caller], [Monitor, Driver],  [Cycle-MacOS]
 
 Dependencies:
 
 1.
 [Cocoa]
 [Cycle-Mac, Driver]
 [Monitor]
 
 2.
 [Driver]
 [Caller]
 
 */

extension Event {
  func coerced() -> [AnyHashable: Any] { return
    [
      "drivers": drivers.map {[
        "label": $0.label,
        "action": $0.action,
        "id": $0.id
      ]},
      "cause": [
        "label": cause.label,
        "action": cause.action,
        "id": cause.id
      ],
      "effect": effect,
      "context": context,
      "pendingEffectEdit": pendingEffectEdit ?? ""
    ]
  }
}

extension CycleMonitorApp.Model {
  var saveFile: [AnyHashable: Any] { return
    [
      "selectedIndex": timeLineView.selectedIndex as Any,
      "events": events.map { $0.coerced() as [AnyHashable: Any] }
    ]
  }
}

extension Event {
  var testFile: [AnyHashable: Any] { return
    [
      "drivers": drivers.map {[
        "label": $0.label,
        "action": $0.action,
        "id": $0.id
      ]},
      "cause": [
        "label": cause.label,
        "action": cause.action,
        "id": cause.id
      ],
      "context": context,
      "effect": effect
    ]
  }
}

extension Int {
  func goldenRatioColored(brightness: CGFloat = 0.95) -> NSColor {
    let bounded = self % (256 * 256 * 256)
    let hue = CGFloat(bounded % 256) / CGFloat(255.0)
    let withGoldenRatio = hue + 0.618033988749895
    return NSColor(
      hue: withGoldenRatio.truncatingRemainder(dividingBy: 1.0),
      saturation: 0.75,
      brightness: brightness,
      alpha: 1.0
    )
  }
}

import Argo
import Runes
import Curry

extension Event: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<Event> { return
    curry(Event.init)
      <^> json <|| "drivers"
      <*> json <| "cause"
      <*> json <| "effect"
      <*> json <| "context"
      <*> json <|? "pendingEffectEdit"
      <*> (json <| "isApproved" <|> .success(false))
  }
}

extension Event.Driver: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<Event.Driver> {
    return curry(Event.Driver.init)
      <^> json <| "label"
      <*> json <| "action"
      <*> json <| "id"
  }
}

extension TimeLineViewController.Model.Driver: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<TimeLineViewController.Model.Driver> {
    return curry(TimeLineViewController.Model.Driver.init)
      <^> json <| "label"
      <*> json <|? "action"
      <*> json <| "id"
  }
}

extension TimeLineViewController.Model.Driver {
  init(label: String, action: String?, id: String) {
    self.init(
      label: label,
      action: action,
      background: id.hashValue.goldenRatioColored(),
      side: id.hashValue.goldenRatioColored(
        brightness: action.map { $0.characters.count == 0 ? 0.95 : 0.5 } ?? 0.95
      )
    )
  }
}

extension MenuBarDriver.Model.Item {
  
  static var openTimelineID = "open timeline"
  static var saveTimelineID = "save timeline"
  static var exportTestsID = "export tests"
  
  static var openTimeline: MenuBarDriver.Model.Item { return
    MenuBarDriver.Model.Item(
      title: "Open Timeline",
      enabled: true,
      id: openTimelineID
    )
  }
  static var saveTimeline: MenuBarDriver.Model.Item { return
    MenuBarDriver.Model.Item(
      title: "Save Timeline",
      enabled: true,
      id: saveTimelineID
    )
  }
  static var exportTests: MenuBarDriver.Model.Item { return
    MenuBarDriver.Model.Item(
      title: "Export Tests",
      enabled: true,
      id: exportTestsID
    )
  }
}

// Cycle Application Delegate

class CycledApplicationDelegate:
      NSObject,
      NSApplicationDelegate {
  
  private var cycle: Cycle<CycleMonitorApp>
  var main: NSWindowController?
  
  public override init() {
    cycle = Cycle(transformer: CycleMonitorApp())
    super.init()
  }
  
  func applicationWillFinishLaunching(_ notification: Notification) {
    main = NSStoryboard(name : "Main", bundle: nil)
      .instantiateController(withIdentifier: "MainWindow") as? NSWindowController
    main?.window?.contentViewController = cycle.root
    main?.window?.makeKeyAndOrderFront(nil)
  }
  
  override open func forwardingTarget(for input: Selector!) -> Any? { return
    cycle.delegate
  }
  
  override open func responds(to input: Selector!) -> Bool {
    if input == #selector(applicationWillFinishLaunching(_:)) {
      applicationWillFinishLaunching(
        Notification(
          name: Notification.Name(
            rawValue: ""
          )
        )
      )
    }
    return cycle.delegate.responds(
      to: input
    )
  }
  
}

// Cycle Mac

public final class Cycle<E: SinkSourceConverting> {
  private var events: Observable<E.Source>?
  private var eventsProxy: ReplaySubject<E.Source>?
  private let cleanup = DisposeBag()
  fileprivate let delegate: NSApplicationDelegate
  fileprivate let root: NSViewController
  private let drivers: E.Drivers
  public required init(transformer: E) {
    eventsProxy = ReplaySubject.create(
      bufferSize: 1
    )
    drivers = transformer.driversFrom(initial: E.Source())
    root = drivers.screen.root
    delegate = drivers.application
    events = transformer.effectsFrom(
      events: eventsProxy!,
      drivers: drivers
    )
    // `.startWith` is redundant, but necessary to kickoff cycle
    // Possibly removed if `events` was BehaviorSubject?
    // Not sure how to `merge` observables to single BehaviorSubject though.
    events?
      .startWith(E.Source())
      .observeOn(SerialDispatchQueueScheduler(qos: .default))
      .subscribe { [weak self] in
        self?.eventsProxy?.on($0)
      }
      .disposed(by: cleanup)
  }
}

public protocol SinkSourceConverting {
  associatedtype Source: Initializable
  associatedtype Drivers: NSApplicationDelegateProviding, ScreenDrivable
  func driversFrom(initial: Source) -> Drivers
  func effectsFrom(events: Observable<Source>, drivers: Drivers) -> Observable<Source>
}

public protocol Initializable {
  init()
}

public protocol ScreenDrivable {
  associatedtype Driver: NSViewControllerProviding
  var screen: Driver { get }
}

public protocol NSViewControllerProviding {
  var root: NSViewController { get }
}

public protocol NSApplicationDelegateProviding {
  associatedtype Delegate: NSApplicationDelegate
  var application: Delegate { get }
}

