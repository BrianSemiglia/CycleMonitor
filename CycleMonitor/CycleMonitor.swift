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
import Cycle
import Argo
import Runes
import Curry

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    
    var lens: CycledLens<
        (TimeLineViewController,
        MultipeerJSON,
        BrowserDriver,
        MenuBarDriver,
        TerminationDriver),
        CycleMonitorApp.Model
    >?
    let cleanup = DisposeBag()
    var main: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        
        self.lens = CycledLens { state in
            let view = state.lens(
                lifter: TimeLineViewController.Model.coerced,
                driver: TimeLineViewController.new(
                    model: .empty
                ),
                reducer: reduced
            )
                        
            let multipeer = state.lens(
                get: { states in
                    MultipeerJSON()
                        .rendering(
                            Observable
                                .merge([
                                  states.connection,
                                  states.jsonEvents,
                                  states.jsonEffects
                                ])
                                .lastTwo()
                        ) { driver, states in
                            driver.render(
                                old: states.0,
                                new: states.1
                            )
                        }
                },
                set: { driver, states in
                    driver.output.tupledWithLatestFrom(states).reduced()
                }
            )
            
            let browser = state.lens(
                lifter: { $0.browser },
                driver: BrowserDriver(
                    initial: BrowserDriver.Model(
                        state: .opening
                    )
                ),
                reducer: reduced
            )
            
            let menuBar = state.lens(
                lifter: { $0.menuBar },
                driver: MenuBarDriver(
                    model: MenuBarDriver.Model(
                        items: []
                    )
                ),
                reducer: reduced
            )
            
            let terminator = state.lens(
                lifter: { TerminationDriver.Model(shouldTerminate: $0.isTerminating) },
                driver: TerminationDriver(
                    model: TerminationDriver.Model(
                        shouldTerminate: false
                    )
                ),
                reducer: { m, e in m } // has no outputs. make optional?
            )
            
            return MutatingLens<Any, Any, Any>
                .zip(
                    view,
                    multipeer,
                    browser,
                    menuBar,
                    terminator
                )
                .prefixed(
                    with: CycleMonitorApp.Model.init()
                )
        }
        
        main = NSStoryboard(
            name: "Main",
            bundle: nil
        )
        .instantiateController(
            withIdentifier: "MainWindow"
        )
        as? NSWindowController

        main?.window?.contentViewController = lens?.receiver.0
        main?.window?.makeKeyAndOrderFront(nil)
    }
}

struct CycleMonitorApp {
    struct Model: Equatable {
        enum EventHandlingState: Equatable {
            case playing
            case playingSendingEvents
            case playingSendingEffects
            case recording
        }
        struct TimeLineView: Equatable {
            var selectedIndex: Int?
        }
        enum Connection: Equatable {
            case idle
            case disconnected
            case connecting
            case connected
        }
        struct Device: Equatable {
            var name: String
            var connection: Connection
            var peerID: Data
        }
        var events: [Moment] = []
        var timeLineView = TimeLineView(
            selectedIndex: nil
        )
        var multipeer = Connection.idle
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
  struct Drivers {
    let screen: TimeLineViewController
    let multipeer: MultipeerJSON
    let browser: BrowserDriver
    let menuBar: MenuBarDriver
    let termination: TerminationDriver
  }
}

extension Observable {
  func secondToLast() -> Observable<Element?> {
    last(2)
    .map { $0.first }
  }
  func lastTwo() -> Observable<(Element?, Element)> {
    last(2)
    .map {
      switch $0.count {
      case 1: return (nil, $0[0])
      case 2: return ($0[0], $0[1])
      default: abort()
      }
    }
  }
  func last(_ count: Int) -> Observable<[Element]> {
    scan ([]) { $0 + [$1] }
    .map { $0.suffix(count) }
    .map (Array.init)
  }
}

extension CycleMonitorApp.Model {
  var selectedEvent: [AnyHashable: Any]? {
    timeLineView
    .selectedIndex
    .flatMap { events[safe: $0] }
    .map { $0.frame.cause.coerced() as [AnyHashable: Any] }
    .map { ["cause": $0] }
  }
  func selectedEffect() -> [AnyHashable: Any]? {
    timeLineView
    .selectedIndex
    .flatMap { events[safe: $0] }
    .map { ["effect": $0.frame.effect] }
  }
}

extension Observable where Element == CycleMonitorApp.Model {
  var connection: Observable<MultipeerJSON.Model> {
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
  var jsonEvents: Observable<MultipeerJSON.Model> {
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
  
  var jsonEffects: Observable<MultipeerJSON.Model> {
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
  func selectedEffect() -> String? {
    timeLineView.selectedIndex
        .flatMap { events[safe: $0] }
        .flatMap { $0.frame.effect }
  }
}

extension Data {
  // TODO: Convert to result type
  var JSON: [AnyHashable: Any]? {
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
    x.coerced()
  }
}

extension Moment.Driver {
    func coerced() -> TimeLineViewController.Model.Driver {
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
    x.coerced()
  }
}

extension Moment {
  func coerced() -> TimeLineViewController.Model.CauseEffect {
    TimeLineViewController.Model.CauseEffect(
        cause: frame.cause.action,
        effect: frame.effect,
        approved: frame.isApproved,
        color: frame.cause.id.hashValue.goldenRatioColored()
    )
  }
}

extension TimeLineViewController.Model {
  static func coerced(_ x: CycleMonitorApp.Model) -> TimeLineViewController.Model {
    x.coerced()
  }
}

extension CycleMonitorApp.Model {
  func coerced() -> TimeLineViewController.Model {
    TimeLineViewController.Model(
      drivers: events[safe: timeLineView.selectedIndex ?? 0]
        .map { $0.drivers.map (Moment.Driver.coerced) }
        ?? []
      ,
      causesEffects: events.map (TimeLineViewController.Model.CauseEffect.coerced),
      presentedState: events[safe: timeLineView.selectedIndex ?? 0]
        .map { $0.frame.effect }
        .flatMap { $0.syntaxHighlighted }
        ?? NSAttributedString(string: ""),
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
    index < count ? self[index] : nil
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
  static var cy_lightGray: NSColor {
    NSColor(
      red: 232.0/255.0,
      green: 232.0/255.0,
      blue: 232.0/255.0,
      alpha: 1
    )
  }
}

extension ObservableType {
  func tupledWithLatestFrom<T>(_ input: Observable<T>) -> Observable<(Element, T)> {
    withLatestFrom(input) { ($0, $1 ) }
  }
}

func reduced(context: CycleMonitorApp.Model, event: TimeLineViewController.Action) -> CycleMonitorApp.Model {
    switch event {
    case .scrolledToIndex(let index):
        var new = context
        new.timeLineView.selectedIndex = index
        return new
    case .toggledApproval(let index, let isApproved):
        var new = context
        new.events[index].frame.isApproved = isApproved
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
        new.events[new.timeLineView.selectedIndex!].frame.effect = newState
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

extension ObservableType where Element == (MultipeerJSON.Action, CycleMonitorApp.Model) {
  func reduced() -> Observable<CycleMonitorApp.Model> {
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

extension Moment {
  static func eventsFrom(_ input: [AnyHashable: Any]) -> [Moment] {
    input["events"]
      .flatMap { $0 as? [[AnyHashable: Any]] }
      .flatMap { $0.compactMap(Argo.decode) }
      ?? []
  }
}

extension CycleMonitorApp.Model.TimeLineView {
  static func timelineViewFrom(
    _ input: [AnyHashable: Any]
  ) -> CycleMonitorApp.Model.TimeLineView {
    CycleMonitorApp.Model.TimeLineView(
      selectedIndex: input["selectedIndex"].flatMap(decode)
    )
  }
}

func reduced(context: CycleMonitorApp.Model, event: BrowserDriver.Action) -> CycleMonitorApp.Model {
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

func reduced(context: CycleMonitorApp.Model, event: MenuBarDriver.Action) -> CycleMonitorApp.Model {
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
                .filter { $0.frame.isApproved }
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

extension CycleMonitorApp.Model {
  var timelineFile: [AnyHashable: Any] {
    [
      "selectedIndex": timeLineView.selectedIndex ?? "",
      "events": events.map { $0.testFile }
    ]
  }
}

extension Moment {
  var testFile: [AnyHashable: Any] {
    [
      "drivers": drivers.map {[
        "label": $0.label,
        "action": $0.action,
        "id": $0.id
      ]},
      "cause": frame.cause.coerced() as [AnyHashable: Any],
      "context": frame.context,
      "effect": frame.effect
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
  
  static var openTimeline: MenuBarDriver.Model.Item {
    MenuBarDriver.Model.Item(
      title: "Open Timeline",
      enabled: true,
      id: openTimelineID
    )
  }
  static var saveTimeline: MenuBarDriver.Model.Item {
    MenuBarDriver.Model.Item(
      title: "Save Timeline",
      enabled: true,
      id: saveTimelineID
    )
  }
  static var exportTests: MenuBarDriver.Model.Item {
    MenuBarDriver.Model.Item(
      title: "Export Tests",
      enabled: true,
      id: exportTestsID
    )
  }
}

import Highlightr

extension String {
    var syntaxHighlighted: NSAttributedString? {
        Highlightr()?.highlight(
            self,
            as: "swift"
        )
    }
}
