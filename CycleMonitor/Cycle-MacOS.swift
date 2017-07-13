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
    main = NSStoryboard(name : "Main", bundle: nil).instantiateController(withIdentifier: "MainWindow") as? NSWindowController
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
    return cycle.delegate.responds(to: input)
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
      selectedIndex: 0,
      focused: 0,
      connection: .disconnected
    )
    var driversTimeline: [[ViewController.Model.Driver]] = []
    var application = AppDelegateStub.Model()
  }
  struct Drivers: NSApplicationDelegateProviding, ScreenDrivable {
    let screen: ViewController
    let json: MultipeerJSON
    let application: AppDelegateStub
  }
  func driversFrom(initial: CycleMonitorApp.Model) -> CycleMonitorApp.Drivers { return
    Drivers(
      screen: ViewController.new(model: initial.screen),
      json: MultipeerJSON(),
      application: AppDelegateStub()
    )
  }
  func effectsFrom(events: Observable<Model>, drivers: Drivers) -> Observable<Model> {
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
    
    return Observable.of(
      screen,
      application,
      json
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
      if case .scrolledToIndex(let index) = event {
        var new = context
        new.screen.drivers = context.driversTimeline[index]
        new.screen.presentedState = context.screen.causesEffects[index].effect
        new.screen.selectedIndex = index
        return new
      } else {
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
        if
        let drivers = data["drivers"] as? [[AnyHashable: Any]],
        let action = data["action"] as? String,
        let effect = data["effect"] as? String {
          var new = context
          
          let newest: [ViewController.Model.Driver]? = drivers.flatMap {
            if let label = $0["label"].flatMap({ $0 as? String }) {
              return ViewController.Model.Driver(
                name: label,
                action: $0["action"].flatMap({ $0 as? String }) ?? "",
                color: $0["action"].flatMap({ $0 as? String }) == nil ? .yellow : .red
              )
            } else {
              return nil
            }
          }
          
          new.driversTimeline = new.driversTimeline + (newest.map { [$0] } ?? [[]])
          new.screen.drivers = newest ?? []
          new.screen.presentedState = effect
          new.screen.causesEffects = context.screen.causesEffects + [
            ViewController.Model.CauseEffect(
              cause: action,
              effect: effect
            )
          ]
          new.screen.focused = new.screen.causesEffects.count - 1
          return new
        } else {
          return context
        }
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
