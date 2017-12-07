//
//  Cycle-MacOS.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import RxSwift
import RxSwiftExt

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
    struct Device {
      var name: String
      var connection: Connection
      var peerID: Data
    }
    var events: [Moment] = []
    var timeLineView = TimeLineView(
      selectedIndex: nil
    )
    var multipeer = Connection.idle
    var application = AppDelegateStub.Model()
    var browser = BrowserDriver.Model(state: .idle)
    var menuBar = MenuBarDriver.Model(
      items: [
        .openTimeline,
        .saveTimeline,
        .exportTests
      ]
    )
    var eventHandlingState = EventHandlingState.playing
    var isTerminating = false
    var devices: [Device] = []
    var selectedPeer: Data?
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

    let multipeer = drivers
      .multipeer
      .rendered(
        Observable.merge([
          events.connection,
          events.jsonEvents,
          events.jsonEffects
        ])
        .lastTwo()
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

extension Observable {
  func secondToLast() -> Observable<E?> { return
    last(2)
    .map { $0.first }
  }
  func lastTwo() -> Observable<(E?, E)> { return
    last(2)
    .map {
      switch $0.count {
      case 1: return (nil, $0[0])
      case 2: return ($0[0], $0[1])
      default: abort()
      }
    }
  }
  func last(_ count: Int) -> Observable<[E]> { return
    scan ([]) { $0 + [$1] }
    .map { $0.suffix(count) }
    .map (Array.init)
  }
}

extension CycleMonitorApp.Model.TimeLineView: Equatable {
  static func ==(
    left: CycleMonitorApp.Model.TimeLineView,
    right: CycleMonitorApp.Model.TimeLineView
  ) -> Bool { return
    left.selectedIndex == right.selectedIndex
  }
}

extension CycleMonitorApp.Model {
  var selectedEvent: [AnyHashable: Any]? { return
    timeLineView
    .selectedIndex
    .flatMap { events[safe: $0] }
    .map { $0.cause.coerced() as [AnyHashable: Any] }
    .map { ["cause": $0] }
  }
  func selectedEffect() -> [AnyHashable: Any]? { return
    timeLineView
    .selectedIndex
    .flatMap { events[safe: $0] }
    .map { ["effect": $0.effect] }
  }
}

extension Observable where E == CycleMonitorApp.Model {
  var connection: Observable<MultipeerJSON.Model> { return
    flatMap { model in
      Observable<MultipeerJSON.Model>.concat(
        model
        .devices
        .map { x -> MultipeerJSON.Model in
          switch x.connection {
          case .disconnected:
            return .idle
          case .connecting:
            return .connecting(peer: x.peerID)
          default:
            return model.selectedPeer == x.peerID
              ? .connecting(peer: x.peerID)
              : .idle
          }
        }
        .map(Observable<MultipeerJSON.Model>.just)
      )
    }
  }
  var jsonEvents: Observable<MultipeerJSON.Model> { return
    filter { $0.eventHandlingState == .playingSendingEvents }
    .distinctUntilChanged { $0.timeLineView.selectedIndex == $1.timeLineView.selectedIndex }
    .flatMap { model in
      Observable<MultipeerJSON.Model>.concat(
        model
        .devices
        .map { device in
          device.peerID == model.selectedPeer
            ? (curry(MultipeerJSON.Model.sending) <^> model.selectedEvent <*> device.peerID) ?? .idle
            : .idle
        }
        .map(Observable<MultipeerJSON.Model>.just)
      )
    }
  }
  
  var jsonEffects: Observable<MultipeerJSON.Model> { return
    filter { $0.eventHandlingState == .playingSendingEffects }
    .distinctUntilChanged {
      let a = curry(==) <^> $0.selectedEffect() as String? <*> $1.selectedEffect() as String?
      return a ?? false
    }
    .flatMap { model in
      Observable<MultipeerJSON.Model>.concat(
        model.devices.map { device in
          device.peerID == model.selectedPeer
            ? (curry(MultipeerJSON.Model.sending) <^> model.selectedEffect() <*> device.peerID) ?? .idle
            : .idle
        }
        .map(Observable<MultipeerJSON.Model>.just)
      )
    }
  }
}

extension CycleMonitorApp.Model {
  func selectedEffect() -> String? { return
    timeLineView.selectedIndex
      .flatMap { events[safe: $0] }
      .flatMap { $0.effect }
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

extension Moment.Driver {
  static func coerced(_ x: Moment.Driver) -> TimeLineViewController.Model.Driver {
    return x.coerced()
  }
}

extension Moment.Driver {
    func coerced() -> TimeLineViewController.Model.Driver { return
        TimeLineViewController.Model.Driver(
            label: label,
            action: action,
            background: id.hashValue.goldenRatioColored(),
            side: id.hashValue.goldenRatioColored(
                brightness: action.count == 0 ? 0.95 : 0.5
            )
        )
    }
}

extension TimeLineViewController.Model.CauseEffect {
  static func coerced(_ x: Moment) -> TimeLineViewController.Model.CauseEffect {
    return x.coerced()
  }
}

extension Moment {
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
        .map { $0.drivers.map (Moment.Driver.coerced) }
        ?? []
      ,
      causesEffects: events.map (TimeLineViewController.Model.CauseEffect.coerced),
      presentedState: events[safe: timeLineView.selectedIndex ?? 0].map { $0.effect } ?? "",
      selected: TimeLineViewController.Model.Selection(
        color: .cy_lightGray,
        index: timeLineView.selectedIndex ?? 0
      ),
      connection: multipeer.timeLineViewControllerConnection,
      eventHandlingState: eventHandlingState.timeLineEventHandlingState,
      devices: devices.map {
        TimeLineViewController.Model.Device(
          name: $0.name,
          connection: $0.connection.timeLineViewControllerConnection
        )
      }
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
      case .didCreatePendingStateEdit(let newState):
        var new = context
        new.events[new.timeLineView.selectedIndex!].effect = newState
        return new
      case .didSelectClearAll:
        var new = context
        new.events = []
        new.timeLineView.selectedIndex = nil
        return new
      case .didSelectItemWith(id: let id):
        var new = context
        new.selectedPeer = context.devices.filter { $0.name == id }.first?.peerID
        new.devices = context.devices.map {
          var x = $0
          x.connection = id != $0.name ? .idle : .connecting
          return x
        }
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
      case .received(let data, let peer) where context.eventHandlingState == .recording && peer == context.selectedPeer:
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
      case .didFind(let name, let id):
        var new = context
        new.devices += [
          CycleMonitorApp.Model.Device(
            name: name,
            connection: .disconnected,
            peerID: id
          )
        ]
        return new
      case .connected(let id):
        var new = context
        new.devices = new.devices.map {
          var x = $0
          x.connection = $0.peerID == id ? .connected : $0.connection
          return x
        }
        new.multipeer = .connected
        return new
      case .connecting:
        var new = context
        new.multipeer = .connecting
        return new
      case .disconnected(let id):
        var new = context
        new.selectedPeer = nil
        new.devices = new.devices.map {
          var x = $0
          x.connection = $0.peerID == id ? .disconnected : $0.connection
          return x
        }
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

extension Moment {
  static func eventsFrom(_ input: [AnyHashable: Any]) -> [Moment] { return
    input["events"]
      .flatMap { $0 as? [[AnyHashable: Any]] }
      .flatMap { $0.flatMap(Argo.decode) }
      ?? []
  }
}

extension CycleMonitorApp.Model.TimeLineView {
  static func timelineViewFrom(
    _ input: [AnyHashable: Any]
  ) -> CycleMonitorApp.Model.TimeLineView { return
    CycleMonitorApp.Model.TimeLineView(
      selectedIndex: input["selectedIndex"].flatMap(decode)
    )
  }
}

extension ObservableType where E == (BrowserDriver.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .didOpen(let json):
        var new = context
        new.events = Moment.eventsFrom(json)
        new.timeLineView = CycleMonitorApp.Model.TimeLineView.timelineViewFrom(json)
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
          context.timelineFile
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

extension CycleMonitorApp.Model {
  var timelineFile: [AnyHashable: Any] { return
    [
      "selectedIndex": timeLineView.selectedIndex ?? "",
      "events": events.map { $0.testFile }
    ]
  }
}

extension Moment {
  var testFile: [AnyHashable: Any] { return
    [
      "drivers": drivers.map {[
        "label": $0.label,
        "action": $0.action,
        "id": $0.id
      ]},
      "cause": cause.coerced() as [AnyHashable: Any],
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

extension Moment: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<Moment> {
    return curry(Moment.init)
      <^> (json <|| "drivers")
        .map(NonEmptyArray.init)
        .flatMap(Decoded<NonEmptyArray<Moment>>.fromOptional)
      <*> json <| "cause"
      <*> json <| "effect"
      <*> json <| "context"
      <*> (json <| "isApproved" <|> .success(false))
  }
}

extension Moment.Driver: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<Moment.Driver> {
    return curry(Moment.Driver.init)
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
        brightness: action.map { $0.count == 0 ? 0.95 : 0.5 } ?? 0.95
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

//extension CycleMonitorApp.Model.Connection {
//  func coerced() -> MultipeerJSON.Model.Device.ConnectionState {
//    switch self {
//    case .connected: return .connected
//      
//    }
//  }
//}

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
