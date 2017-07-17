//
//  Cycle-MacOS.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/4/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import RxSwift

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
    var screen = ViewController.Model(
      drivers: [],
      causesEffects: [],
      presentedState: "",
      selected: nil,
      focused: 0,
      connection: .disconnected
    )
    var driversTimeline: [[ViewController.Model.Driver]] = []
    var application = AppDelegateStub.Model()
    var browser = BrowserDriver.Model(state: .idle)
    var menuBar = MenuBarDriver.Model(
      items: [
        MenuBarDriver.Model.Item(
          title: "Import",
          enabled: true,
          id: "import"
        )
      ]
    )
  }
  struct Drivers: NSApplicationDelegateProviding, ScreenDrivable {
    let screen: ViewController
    let json: MultipeerJSON
    let application: AppDelegateStub
    let browser: BrowserDriver
    let menuBar: MenuBarDriver
  }
  func driversFrom(initial: CycleMonitorApp.Model) -> CycleMonitorApp.Drivers { return
    Drivers(
      screen: ViewController.new(
        model: initial.screen
      ),
      json: MultipeerJSON(),
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
      .rendered(events.map { $0.screen })
      .tupledWithLatestFrom(events)
      .reduced()
    
    let application = drivers
      .application
      .rendered(events.map { $0.application })
      .tupledWithLatestFrom(events)
      .reduced()
    
    let json = drivers.json.output
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
      json,
      browser,
      menuBar
    ).merge()
  }
}

extension ObservableType {
  func tupledWithLatestFrom<T>(_ input: Observable<T>) -> Observable<(E, T)> {
    return withLatestFrom(input) { ($0.0, $0.1 ) }
  }
}

extension ObservableType where E == (ViewController.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> { return
    map { event, context in
      switch event {
      case .scrolledToIndex(let index):
        var new = context
        new.screen.drivers = context.driversTimeline[index]
        new.screen.presentedState = context.screen.causesEffects[index].effect
        new.screen.selected = ViewController.Model.Selection(
          color: NSColor(
            red: 232.0/255.0,
            green: 232.0/255.0,
            blue: 232.0/255.0,
            alpha: 1
          ),
          index: index
        )
        return new
      case .toggledApproval(let index, let isApproved):
        var new = context
        new.screen.causesEffects[index].approved = isApproved
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
      case .received(let data):
        var new = context
        new.driversTimeline += data["drivers"].flatMap(decode).map {[$0]} ?? [[]]
        new.screen.drivers = data["drivers"].flatMap(decode) ?? []
        new.screen.presentedState = data["effect"].flatMap(decode) ?? ""
        new.screen.causesEffects += decode(data).map {[$0]} ?? []
        new.screen.focused = new.screen.causesEffects.count - 1
        return new
      case .connected:
        var new = context
        new.screen.connection = .connected
        return new
      case .connecting:
        var new = context
        new.screen.connection = .connecting
        return new
      case .disconnected:
        var new = context
        new.screen.connection = .disconnected
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
      case .didOpen:
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
      case .didSelectItemWith(id: let id) where id == "import":
        var new = context
        new.browser.state = .opening
        return new
      default:
        break
      }
      return context
    }
  }
}

import Argo
import Runes
import Curry

extension ViewController.Model.Driver: Decodable {
  static func decode(_ json: JSON) -> Decoded<ViewController.Model.Driver> {
    return curry(ViewController.Model.Driver.init)
      <^> json <| "label"
      <*> json <|? "action"
  }
}

extension ViewController.Model.Driver {
  init(label: String, action: String?) {
    self.init(
      label: label,
      action: action,
      color: action == nil ? .yellow : .red
    )
  }
}

extension ViewController.Model.CauseEffect: Decodable {
  public static func decode(_ json: JSON) -> Decoded<ViewController.Model.CauseEffect> {
    return curry(ViewController.Model.CauseEffect.init)
      <^> json <| "action"
      <*> json <| "effect"
      <*> .success(false) // need to find a way to honor default (vs. setting here)
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
      .subscribe { [weak self] in
        self?.eventsProxy?.on($0)
      }.disposed(by: cleanup)
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

