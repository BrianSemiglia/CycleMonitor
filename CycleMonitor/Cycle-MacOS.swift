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
      case playingSending
      case recording
    }
    struct Event {
      struct Driver {
        var label: String
        var action: String
        var id: String
      }
      var drivers: [Driver]
      var cause: Driver
      var effect: String
      var pendingEffectEdit: String?
      var isApproved = false
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
        MenuBarDriver.Model.Item(
          title: "Open",
          enabled: true,
          id: "open"
        ),
        MenuBarDriver.Model.Item(
          title: "Save",
          enabled: true,
          id: "save"
        )
      ]
    )
    var eventHandlingState = EventHandlingState.playing
  }
  struct Drivers: NSApplicationDelegateProviding, ScreenDrivable {
    let screen: TimeLineViewController
    let multipeer: MultipeerJSON
    let application: AppDelegateStub
    let browser: BrowserDriver
    let menuBar: MenuBarDriver
  }
  func driversFrom(initial: CycleMonitorApp.Model) -> CycleMonitorApp.Drivers { return
    Drivers(
      screen: TimeLineViewController.new(
        model: initial.asModel
      ),
      multipeer: MultipeerJSON(),
      application: AppDelegateStub(),
      browser: BrowserDriver(
        initial: initial.browser
      ),
      menuBar: MenuBarDriver(
        model: initial.menuBar
      )
    )
  }
  func effectsFrom(
    events: Observable<Model>,
    drivers: Drivers
  ) -> Observable<Model> {
    let screen = drivers
      .screen
      .rendered(events.map { $0.asModel })
      .tupledWithLatestFrom(events)
      .reduced()
    
    let application = drivers
      .application
      .rendered(events.map { $0.application })
      .tupledWithLatestFrom(events)
      .reduced()

    let multipeer = drivers.multipeer
      .rendered(
        events
          .filter { $0.eventHandlingState == .playingSending }
          .map {
            $0.events[$0.timeLineView.selectedIndex!].pendingEffectEdit
              .map { $0.data(using: .utf8) } ??
            $0.events[$0.timeLineView.selectedIndex!].effect.data(using: .utf8)
          }
          .filterNil()
          .map { $0.JSON }
          .filterNil()
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
    
    return Observable.of(
      screen,
      application,
      multipeer,
      browser,
      menuBar
    ).merge()
  }
}

extension Data {
  var JSON: [AnyHashable: Any]? {
    do {
      return try JSONSerialization.jsonObject(
        with: self,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      ) as? [AnyHashable: Any]
    } catch let error {
      print(error)
      return nil
    }
  }
}

extension CycleMonitorApp.Model.EventHandlingState {
  var asTimeLineEventHandlingState: TimeLineViewController.Model.EventHandlingState {
    switch self {
    case .playing: return .playing
    case .playingSending: return .playingSending
    case .recording: return .recording
    }
  }
}

extension CycleMonitorApp.Model {
  var asModel: TimeLineViewController.Model { return
    TimeLineViewController.Model(
      drivers: timeLineView.selectedIndex.map {
        events[$0].drivers.map {
          TimeLineViewController.Model.Driver(
            label: $0.label,
            action: $0.action,
            background: $0.id.hashValue.goldenRatioColored(),
            side: $0.id.hashValue.goldenRatioColored(
              brightness: $0.action.characters.count == 0 ? 0.95 : 0.5
            )
          )
        }
      } ?? [],
      causesEffects: events.map {
        TimeLineViewController.Model.CauseEffect(
          cause: $0.cause.action,
          effect: $0.effect,
          color: $0.cause.id.hashValue.goldenRatioColored()
        )
      },
      presentedState: timeLineView.selectedIndex
        .map { events[$0].pendingEffectEdit ?? events[$0].effect }
        ?? "",
      selected: timeLineView.selectedIndex.map {
        TimeLineViewController.Model.Selection(
          color: NSColor.cy_lightGray,
          index: $0
        )
      },
      connection: multipeer.asTimeLineViewControllerConnection,
      eventHandlingState: eventHandlingState.asTimeLineEventHandlingState,
      isDisplayingSave: timeLineView.selectedIndex
        .map { 
          events[$0].pendingEffectEdit != nil && 
          events[$0].pendingEffectEdit != events[$0].effect
        }
        ?? false
    )
  }
}

extension CycleMonitorApp.Model.Connection {
  var asTimeLineViewControllerConnection: TimeLineViewController.Model.Connection {
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
  func tupledWithLatestFrom<T>(_ input: Observable<T>) -> Observable<(E, T)> {
    return withLatestFrom(input) { ($0.0, $0.1 ) }
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
        case .playingSending:
          var new = context
          new.eventHandlingState = .playingSending
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
        new.events += data.JSON
          .flatMap(CycleMonitorApp.Model.Event.decode)
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

extension ObservableType where E == (BrowserDriver.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .didOpen(let json):
        var new = context
        new.events = json["events"]
          .flatMap { $0 as? [[AnyHashable: Any]] }
          .flatMap { $0.flatMap(CycleMonitorApp.Model.Event.decode) }
          ?? []
        new.timeLineView.selectedIndex = json["selectedIndex"].flatMap(decode)
        new.browser.state = .idle
        return new
      case .cancelling:
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
      case .didSelectItemWith(id: let id) where id == "open":
        var new = context
        new.browser.state = .opening
        return new
      case .didSelectItemWith(id: let id) where id == "save":
        var new = context
        new.browser.state = .saving(context.saveFile)
        return new
      default:
        break
      }
      return context
    }
  }
}

extension CycleMonitorApp.Model {
  var saveFile: [AnyHashable: Any] { return
    [
      "selectedIndex": timeLineView.selectedIndex as Any,
      "events": events.map {
        [
          "drivers": $0.drivers.map {[
            "label": $0.label,
            "action": $0.action,
            "id": $0.id
          ]},
          "cause": [
            "label": $0.cause.label,
            "action": $0.cause.action,
            "id": $0.cause.id
          ],
          "effect": $0.effect.data(using: .utf8)!.JSON!,
          "pendingEffectEdit": $0.pendingEffectEdit.map { $0.data(using: .utf8)!.JSON! } ?? ""
        ]
      }
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

extension CycleMonitorApp.Model.Event {

  static func decode(_ input: [AnyHashable: Any]) -> CycleMonitorApp.Model.Event? {

    let effect = input["effect"]
      .flatMap { $0 as? [AnyHashable: Any] }
      .flatMap {
        try? JSONSerialization.data(
          withJSONObject: $0,
          options: .prettyPrinted
        )
      }
      .flatMap {
        String(data: $0, encoding: String.Encoding.utf8)
      }
    
    let drivers: [CycleMonitorApp.Model.Event.Driver]? = input["drivers"]
      .flatMap { $0 as? [[AnyHashable: Any]] }
      .flatMap {
        $0.flatMap {
          let label = $0["label"].flatMap { $0 as? String }
          let action = $0["action"].flatMap { $0 as? String }
          let id = $0["id"].flatMap { $0 as? String }
          return curry(CycleMonitorApp.Model.Event.Driver.init)
            <^> label
            <*> action
            <*> id
        }
      }
    
    let cause: CycleMonitorApp.Model.Event.Driver? = input["cause"]
      .flatMap { $0 as? [AnyHashable: Any] }
      .flatMap {
        let label = $0["label"].flatMap { $0 as? String }
        let action = $0["action"].flatMap { $0 as? String }
        let id = $0["id"].flatMap { $0 as? String }
        return curry(CycleMonitorApp.Model.Event.Driver.init)
          <^> label
          <*> action
          <*> id
    }
    
    let pendingEffectEdit = input["pendingEffectEdit"]
      .flatMap { $0 as? [AnyHashable: Any] }
      .flatMap {
        try? JSONSerialization.data(
          withJSONObject: $0,
          options: .prettyPrinted
        )
      }
      .flatMap {
        String(data: $0, encoding: String.Encoding.utf8)
      }
      .flatMap { $0.characters.count > 0 ? $0 : nil }
    
    let x = curry(CycleMonitorApp.Model.Event.init)
      <^> drivers
      <*> cause
      <*> effect
      <*> Optional(pendingEffectEdit)
      <*> false
  
    return x
  }
  
}

extension CycleMonitorApp.Model.Event.Driver: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<CycleMonitorApp.Model.Event.Driver> {
    return curry(CycleMonitorApp.Model.Event.Driver.init)
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

