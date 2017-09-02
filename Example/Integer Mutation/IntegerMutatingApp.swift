//
//  IntegerMutatingApp.swift
//  Cycle
//
//  Created by Brian Semiglia on 1/20/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation
import Cycle
import RxSwift
import Curry
import Wrap
import Argo
import Runes

@UIApplicationMain
class Example: CycledApplicationDelegate<IntegerMutatingApp> {
  init() {
    super.init(
      filter: IntegerMutatingApp()
    )
  }
}

struct IntegerMutatingApp: SinkSourceConverting {
  struct Model: Initializable {
    var screen = ValueToggler.Model.empty
    var application = RxUIApplication.Model.empty
    var bugReporter = BugReporter.Model(state: .idle)
    var motionReporter = ShakeDetection.Model(state: .listening)
  }
  struct Drivers: UIApplicationDelegateProviding, ScreenDrivable {
    let screen: ValueToggler
    let application: RxUIApplication
    let multipeer: MultipeerJSON
    let bugReporter: BugReporter
    let motionReporter: ShakeDetection
  }
  func driversFrom(initial: IntegerMutatingApp.Model) -> IntegerMutatingApp.Drivers { return
    Drivers(
      screen: ValueToggler(),
      application: RxUIApplication(initial: initial.application),
      multipeer: MultipeerJSON(),
      bugReporter: BugReporter(initial: initial.bugReporter),
      motionReporter: ShakeDetection(initial: initial.motionReporter)
    )
  }
  func effectsFrom(events: Observable<Model>, drivers: Drivers) -> Observable<Model> {
    let valueActions = drivers
      .screen
      .rendered(events.map { $0.screen })
      .share()
    
    let applicationActions = drivers
      .application
      .rendered(events.map { $0.application })
      .share()

    let valueEffects = valueActions
      .tupledWithLatestFrom(events)
      .reduced()
      .share()

    let applicationEffects = applicationActions
      .tupledWithLatestFrom(events)
      .reduced()
      .share()

    let shakeActions = drivers.motionReporter
      .rendered(events.map { $0.motionReporter })
      .share()
    
    let shakeEffects = shakeActions
      .tupledWithLatestFrom(events)
      .reduced()
      .share()
    
    let dictionaryStateStream: Observable<[AnyHashable: Any]> = Observable.of(
      valueActions
        .tupledWithLatestFrom(valueEffects)
        .tupledWithLatestFrom(events)
        .map {
          $0.0.1.JSONTimelineFrameWith(
            togglerAction: $0.0.0 == .incrementing ? "incrementing" : "decrementing",
            context: $0.1
          )
        },
      applicationActions
        .tupledWithLatestFrom(applicationEffects)
        .tupledWithLatestFrom(events)
        .map {
          $0.0.1.JSONTimelineFrameWith(
            sessionAction: $0.0.0.session.state.string(),
            context: $0.1
          )
        },
      shakeActions
        .tupledWithLatestFrom(shakeEffects)
        .tupledWithLatestFrom(events)
        .map {
          $0.0.1.JSONTimelineFrameWith(
            shakeAction: $0.0.0.string(),
            context: $0.1
          )
        }
      )
      .merge()
      .share()

    let json = drivers.multipeer
      .rendered(dictionaryStateStream)
      .tupledWithLatestFrom(events)
      .reduced()
      .share()

    let reporter = drivers.bugReporter
      .rendered(
        events
          .map { $0.bugReporter }
          .tupledWithLatestFrom(
            dictionaryStateStream
              .scan([[AnyHashable: Any]]()) { $0 + [$1] }
              .map { $0.suffix(25) }
              .map (Array.init)
              .map { ["events": $0] as [AnyHashable: Any] }
          )
          .map {
            switch $0.0.state {
            case .shouldSend:
              var new = $0.0
              if let data = $0.1.binaryPropertyList() {
                new.state = .sending(data)
              } else {
                new.state = .idle
              }
              return new
            default:
              return $0.0
            }
        }
    )
    .tupledWithLatestFrom(events)
    .reduced()
    .share()

    return Observable
      .of(
        valueEffects,
        applicationEffects,
        json,
        reporter,
        shakeEffects
      )
      .merge()
  }
}

extension ShakeDetection.Action {
  func string() -> String {
    switch self {
    case .detecting: return "detecting"
    case .none: return ""
    }
  }
}

extension Change where T == RxUIApplication.Model.Session.State {
  func string() -> String {
    switch self {
    case .currently(let x): return "currently(" + x.string() + ")"
    case .pre(let x): return "pre(" + x.string() + ")"
    }
  }
}

extension RxUIApplication.Model.Session.State {
  func string() -> String {
    switch self {
    case .awaitingLaunch: return "awaitingLaunch"
    case .active(let count): return "active(" + count.string() + ")"
    case .resigned: return "resigned"
    case .terminated: return "terminated"
    }
  }
}

extension RxUIApplication.Model.Session.State.Count {
  func string() -> String {
    switch self {
    case .first(_): return "first"
    case .some: return "some"
    }
  }
}

extension ValueToggler.Model.Button.State {
  func string() -> String {
    switch self {
    case .highlighted: return "highlighted"
    case .enabled: return "enabled"
    }
  }
}

extension IntegerMutatingApp.Model {
  func JSONTimelineFrameWith(
    sessionAction: String,
    context: IntegerMutatingApp.Model
  ) -> [AnyHashable: Any] { return
    [
      "drivers": [
        ["label": "shakes",  "action": "",            "id": "shakes"],
        ["label": "toggler", "action": "",            "id": "toggler"],
        ["label": "session", "action": sessionAction, "id": "session"]
      ],
      "cause": [
        "label": "session",
        "action": sessionAction,
        "id": "session"
      ],
      "context": try! wrap(context) as [String: Any],
      "effect": try! wrap(self) as [String: Any]
    ]
  }
  func JSONTimelineFrameWith(
    togglerAction: String,
    context: IntegerMutatingApp.Model
  ) -> [AnyHashable: Any] { return
    [
      "drivers": [
        ["label": "shakes",  "action": "",            "id": "shakes"],
        ["label": "toggler", "action": togglerAction, "id": "toggler"],
        ["label": "session", "action": "",            "id": "session"]
      ],
      "cause": [
        "label": "toggler",
        "action": togglerAction,
        "id": "toggler"
      ],
      "context": try! wrap(context) as [String: Any],
      "effect": try! wrap(self) as [String: Any]
    ]
  }
  func JSONTimelineFrameWith(
    shakeAction: String,
    context: IntegerMutatingApp.Model
  ) -> [AnyHashable: Any] { return
    [
      "drivers": [
        ["label": "shakes",  "action": shakeAction, "id": "shakes"],
        ["label": "toggler", "action": "",          "id": "toggler"],
        ["label": "session", "action": "",          "id": "session"]
      ],
      "cause": [
        "label": "shake",
        "action": shakeAction,
        "id": "shakes"
      ],
      "context": try! wrap(context) as [String: Any],
      "effect": try! wrap(self) as [String: Any]
    ]
  }
}

extension IntegerMutatingApp.Model {
  
  static func cause(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Drivers.Either? {
    return input["cause"].flatMap(Argo.decode)
  }
  
  static func context(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
    return input["context"].flatMap(Argo.decode)
  }
  
  static func effect(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
    return input["effect"].flatMap(Argo.decode)
  }
  
  static func reduced(
    driver: IntegerMutatingApp.Drivers.Either,
    context: IntegerMutatingApp.Model
  ) -> Observable<IntegerMutatingApp.Model> {
    switch driver {
    case .valueToggler(let action):
      return Observable.just((action, context)).reduced()
    case .rxUIApplication(let action):
      return Observable.just((action, context)).reduced()
    case .bugReporter(let action):
      return Observable.just((action, context)).reduced()
    case .shakeDetection(let action):
      return Observable.just((action, context)).reduced()
    }
  }

}

extension IntegerMutatingApp.Drivers {
  enum Either {
    case valueToggler(ValueToggler.Action)
    case rxUIApplication(RxUIApplication.Model)
    case bugReporter(BugReporter.Action)
    case shakeDetection(ShakeDetection.Action)
  }
}

extension IntegerMutatingApp.Drivers.Either: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<IntegerMutatingApp.Drivers.Either> {
    switch json {
    case .object(let x) where x["id"] == .string("toggler"): return
      IntegerMutatingApp.Drivers.Either.valueToggler <^> json <| "action"
    case .object(let x) where x["id"] == .string("shakes"): return
      IntegerMutatingApp.Drivers.Either.shakeDetection <^> json <| "action"
    default: return
      .failure(
        .typeMismatch(
          expected: "toggler | shakes",
          actual: json.description
        )
      )
    }
  }
}

// investigate chatty session events

extension Data {
  var JSON: [AnyHashable: Any]? { return
    (
      try? JSONSerialization.jsonObject(
        with: self,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      )
    )
    .flatMap { $0 as? [AnyHashable: Any] }
  }
  var binaryPropertyList: [AnyHashable: Any]? { return
    (
      try? PropertyListSerialization.propertyList(
        from: self,
        options: PropertyListSerialization.MutabilityOptions(rawValue: 0),
        format: nil
      )
    )
    .flatMap { $0 as? [AnyHashable: Any] }
  }
}

extension Collection where Iterator.Element == (key: AnyHashable, value: Any) {
  var JSON: Data? { return
    try? JSONSerialization.data(
      withJSONObject: self,
      options: JSONSerialization.WritingOptions(rawValue: 0)
    )
  }
  func binaryPropertyList() -> Data? { return
    try? PropertyListSerialization.data(
      fromPropertyList: self,
      format: .binary,
      options: 0
    )
  }
}

extension ObservableType {
  func pacedBy(delay: Double) -> Observable<E> { return
    map {
      Observable
        .empty()
        .delay(
          delay,
          scheduler: MainScheduler.instance
        )
        .startWith($0)
    }
    .concat()
  }
}

extension ObservableType {
  func tupledWithLatestFrom<T>(_ input: Observable<T>) -> Observable<(E, T)> {
    return withLatestFrom(input) { ($0.0, $0.1 ) }
  }
}

extension ObservableType where E == (MultipeerJSON.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    flatMap { (event, context) -> Observable<IntegerMutatingApp.Model> in
      switch event {
      case.received(data: let new):
        return new.JSON.flatMap { x in
          let a = curry(IntegerMutatingApp.Model.reduced)
            <^> IntegerMutatingApp.Model.cause(x)
            <*> .some(context)
          let y: Observable<IntegerMutatingApp.Model>? = Observable.just <^> Argo.decode(x)
          return a ?? y
        }
        ?? Observable.just(context)
      default:
        return Observable.just(context)
      }
    }
  }
}

extension IntegerMutatingApp.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<IntegerMutatingApp.Model> {
    return curry(IntegerMutatingApp.Model.init)
      <^> json <| "screen"
      <*> .success(RxUIApplication.Model.empty)
      <*> json <| "bugReporter"
      <*> json <| "motionReporter"
  }
}

extension ValueToggler.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ValueToggler.Model> {
    return curry(ValueToggler.Model.init)
      <^> json <| "total"
      <*> json <| "increment"
      <*> json <| "decrement"
  }
}

extension ValueToggler.Action: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ValueToggler.Action> {
    switch json {
    case .string(let x) where x == "incrementing":
      return .success(.incrementing)
    case .string(let x) where x == "decrementing":
      return .success(.decrementing)
    default:
      return .failure(.custom(""))
    }
  }
}

extension ShakeDetection.Action: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Action> {
    switch json {
    case .string(let x) where x == "none": return .success(.none)
    case .string(let x) where x == "detecting": return .success(.detecting)
    default: return
      .failure(
        .typeMismatch(
          expected: "none | detecting",
          actual: json.description
        )
      )
    }
  }
}

extension ValueToggler.Model.Button: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ValueToggler.Model.Button> {
    return curry(ValueToggler.Model.Button.init)
      <^> json <| "state"
      <*> json <| "title"
  }
}

extension ValueToggler.Model.Button.State: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ValueToggler.Model.Button.State> {
    switch json {
    case .string(let x) where x == "enabled": return .success(.enabled)
    case .string(let x) where x == "highlighted": return .success(.highlighted)
    default: return
      .failure(
        .typeMismatch(
          expected: "enabled | highlighted",
          actual: json.description
        )
      )
    }
  }
}

extension BugReporter.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<BugReporter.Model> {
    return curry(BugReporter.Model.init)
      <^> json <| "state"
  }
}

extension BugReporter.Model.State: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<BugReporter.Model.State> {
    switch json {
    default: return .success(.idle)
    }
  }
}

extension ShakeDetection.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model> {
    return curry(ShakeDetection.Model.init)
      <^> json <| "state"
  }
}

extension ShakeDetection.Model.State: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model.State> {
    switch json {
    case .string(let x) where x == "idle": return .success(.idle)
    case .string(let x) where x == "listening": return .success(.listening)
    default: return .failure(.typeMismatch(expected: "String", actual: ""))
    }
  }
}

extension ObservableType where E == (ShakeDetection.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    map { event, context in
      switch event {
      case .detecting:
        var new = context
        new.bugReporter.state = .shouldSend
        return new
      default:
        return context
      }
    }
  }
}

extension ObservableType where E == (BugReporter.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    map { event, context in
      switch event {
      case .didSuccessfullySend:
        var new = context
        new.bugReporter.state = .idle
        return new
      default:
        return context
      }
    }
  }
}

extension ObservableType where E == (ValueToggler.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    map { event, context in
      switch event {
      case .incrementing:
        var x = context
        x.screen.total = Int(x.screen.total).map { $0 + 1 }.map(String.init) ?? ""
        x.screen.increment.state = .enabled
        return x
      case .decrementing:
        var x = context
        x.screen.total = Int(x.screen.total).map { $0 - 1 }.map(String.init) ?? ""
        x.screen.decrement.state = .enabled
        return x
      }
    }
  }
}

extension ObservableType where E == (RxUIApplication.Model, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    map { event, global in
      var new = global
      new.application.shouldLaunch = true
      if case .pre(.active(.some)) = event.session.state {
        new.screen.total = "55"
      }
      return new
    }
  }
}

extension IntegerMutatingApp.Model: Equatable {
  static func ==(
    left: IntegerMutatingApp.Model,
    right: IntegerMutatingApp.Model
  ) -> Bool { return
    left.screen == right.screen &&
    left.application == right.application &&
    left.bugReporter == right.bugReporter &&
    left.motionReporter == right.motionReporter
  }
}

extension ValueToggler.Model: Equatable {
  static func ==(left: ValueToggler.Model, right: ValueToggler.Model) -> Bool { return
    left.total == right.total &&
    left.increment == right.increment &&
    left.decrement == right.decrement
  }
}

extension ValueToggler.Model.Button: Equatable {
  static func ==(
    left: ValueToggler.Model.Button,
    right: ValueToggler.Model.Button
  ) -> Bool { return
    left.state == right.state &&
    left.title == right.title
  }
}

extension ShakeDetection.Model: Equatable {
  static func ==(
    left: ShakeDetection.Model,
    right: ShakeDetection.Model
  ) -> Bool { return
    left.state == right.state
  }
}
