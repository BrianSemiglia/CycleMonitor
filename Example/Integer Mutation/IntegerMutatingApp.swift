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
import RxSwiftExt
import RxUIApplicationDelegate

@UIApplicationMain
class Example: CycledApplicationDelegate<IntegerMutatingApp> {
  override init() {
    super.init(
      router: IntegerMutatingApp()
    )
  }
}

struct IntegerMutatingApp: IORouter {
  static let seed = Model()
  struct Model {
    var screen = ValueToggler.Model.empty
    var application = RxUIApplicationDelegate.Model.empty
    var bugReporter = BugReporter.Model(state: .idle)
    var motionReporter = ShakeDetection.Model(state: .listening)
  }
  struct Drivers: MainDelegateProviding, ScreenDrivable {
    let screen: ValueToggler
    let application: RxUIApplicationDelegate
    let multipeer: MultipeerJSON
    let bugReporter: BugReporter
    let motionReporter: ShakeDetection
  }
  func driversFrom(seed: IntegerMutatingApp.Model) -> IntegerMutatingApp.Drivers { return
    Drivers(
      screen: ValueToggler(),
      application: RxUIApplicationDelegate(initial: seed.application),
      multipeer: MultipeerJSON(),
      bugReporter: BugReporter(initial: seed.bugReporter),
      motionReporter: ShakeDetection(initial: seed.motionReporter)
    )
  }
  func effectsOfEventsCapturedAfterRendering(
    incoming: Observable<Model>,
    to drivers: Drivers
  ) -> Observable<Model> {
    let valueActions = drivers
      .screen
      .rendered(incoming.map { $0.screen })
      .share()
    
    let applicationActions = drivers
      .application
      .eventsCapturedAfterRendering(incoming.map { $0.application })
      .share()

    let valueEffects = valueActions
      .tupledWithLatestFrom(incoming)
      .reduced()
      .share()

    let applicationEffects = applicationActions
      .tupledWithLatestFrom(incoming)
      .reduced()
      .share()

    let shakeActions = drivers
      .motionReporter
      .rendered(incoming.map { $0.motionReporter })
      .share()
    
    let shakeEffects = shakeActions
      .tupledWithLatestFrom(incoming)
      .reduced()
      .share()
    
    let moments = Observable.merge([
      valueActions
        .tupledWithLatestFrom(
          valueEffects,
          incoming
            .secondToLast()
            .unwrap()
        )
        .map (Moment.coerced)
      ,
      applicationActions
        .tupledWithLatestFrom(
          applicationEffects,
          incoming
            .secondToLast()
            .unwrap()
        )
        .map { action, effect, context in
          effect.coerced(
            sessionAction: wrap(action.session.state)
              .flatMap { $0 as [AnyHashable: Any] }
              .flatMap { $0.description }
              ?? ""
            ,
            context: context
          )
        }
      ,
      shakeActions
        .tupledWithLatestFrom(
          shakeEffects,
          incoming
            .secondToLast()
            .unwrap()
        )
        .map (Moment.coerced)
    ])
    .unwrap()
    .share()

    let json = drivers
      .multipeer
      .rendered(moments.map { $0.playback() })
      .tupledWithLatestFrom(incoming)
      .reduced()
      .share()

    let reporter = drivers
      .bugReporter
      .rendered(
        incoming
          .map { $0.bugReporter }
          .tupledWithLatestFrom(
            moments
              .last(25)
              .map { $0.eventsPlayable }
          )
          .map { reporter, moments in
            switch reporter.state {
            case .shouldSend:
              var new = reporter
              new.state = moments.binaryPropertyList().map(BugReporter.Model.State.sending) ?? .idle
              return new
            default:
              var new = reporter
              new.state = .idle
              return new
            }
          }
      )
      .tupledWithLatestFrom(incoming)
      .reduced()
      .share()

    return .merge([
      valueEffects,
      applicationEffects,
      json,
      reporter,
      shakeEffects
    ])
  }
}

// 1. observe requirements
// 2. render requirements: a. String -> Enum -> Driver.Action b. JSON -> App.Model
// 3. test requirements? same as render?
// 4. section sample code into these categories

extension Collection where Iterator.Element == Moment {
  var eventsPlayable: [AnyHashable: Any] { return
    ["events": map { $0.playback() }]
  }
}

extension Observable {
  func secondToLast() -> Observable<E?> { return
    last(2).map { $0.first }
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

func wrap(_ input: Any) -> String? { return
  wrap(("filler tuple", input))
    .flatMap { $0 as [AnyHashable: Any] }
    .flatMap { $0[".1"] as? String }
}

extension Moment.Driver {
  static func shakesWith(action: String? = nil) -> Moment.Driver { return
    Moment.Driver(
      label: "shakes",
      action: action ?? "",
      id: "shakes"
    )
  }
  static func valueTogglerWith(action: String? = nil) -> Moment.Driver { return
    Moment.Driver(
      label: "toggler",
      action: action ?? "",
      id: "toggler"
    )
  }
  static func sessionWith(action: String? = nil) -> Moment.Driver { return
    Moment.Driver(
      label: "session",
      action: action ?? "",
      id: "session"
    )
  }
}

extension JSONSerialization {
  static func prettyPrinted(_ input: [AnyHashable: Any]) -> Data? { return
    try? JSONSerialization.data(
      withJSONObject: input,
      options: .prettyPrinted
    )
  }
}

extension Data {
  var utf8: String? { return
    String(
      data: self,
      encoding: String.Encoding.utf8
    )
  }
}

extension IntegerMutatingApp.Model {
  func coerced(
    sessionAction: String,
    context: IntegerMutatingApp.Model
  ) -> Moment? { return
    curry(Moment.init(drivers:cause:effect:context:))
      <^> NonEmptyArray(
        Moment.Driver.shakesWith(),
        Moment.Driver.valueTogglerWith(),
        Moment.Driver.sessionWith(action: sessionAction)
      )
      <*> Moment.Driver.sessionWith(
        action: sessionAction
      )
      <*> wrap(self)
        .flatMap (JSONSerialization.prettyPrinted)
        .flatMap { $0.utf8 }
      <*> wrap(context)
        .flatMap (JSONSerialization.prettyPrinted)
        .flatMap { $0.utf8 }
  }
}

extension Moment {
  static func coerced(
    action: ValueToggler.Action,
    effect: IntegerMutatingApp.Model,
    context: IntegerMutatingApp.Model
  ) -> Moment? { return
    curry(Moment.init(drivers:cause:effect:context:))
      <^> wrap(action)
        .map (Moment.Driver.valueTogglerWith)
        .map {[
            Moment.Driver.shakesWith(),
            $0,
            Moment.Driver.sessionWith()
        ]}
        .flatMap (NonEmptyArray.init(possible:))
      <*> wrap(action)
        .map(Moment.Driver.valueTogglerWith)
      <*> wrap(effect)
          .flatMap (JSONSerialization.prettyPrinted)
          .flatMap { $0.utf8 }
      <*> wrap(context)
          .flatMap (JSONSerialization.prettyPrinted)
          .flatMap { $0.utf8 }
  }

  static func coerced(
    action: ShakeDetection.Action,
    effect: IntegerMutatingApp.Model,
    context: IntegerMutatingApp.Model
  ) -> Moment? { return
    curry(Moment.init(drivers:cause:effect:context:))
      <^> wrap(action)
        .map (Moment.Driver.shakesWith)
        .map {[
          $0,
          Moment.Driver.valueTogglerWith(),
          Moment.Driver.sessionWith()
        ]}
        .flatMap (NonEmptyArray.init(possible:))
      <*> wrap(action)
        .map(Moment.Driver.shakesWith)
      <*> wrap(effect)
        .flatMap (JSONSerialization.prettyPrinted)
        .flatMap { $0.utf8 }
      <*> wrap(context)
        .flatMap (JSONSerialization.prettyPrinted)
        .flatMap { $0.utf8 }
  }
}

func wrap(_ input: Any) -> [AnyHashable: Any]? {
  return try? wrap(input) as [AnyHashable: Any]
}

extension IntegerMutatingApp.Model {
  
  static func cause(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Drivers.Either? { return
    input["cause"]
      .flatMap(Argo.decode)
  }
  
  static func context(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? { return
    input["context"]
      .flatMap { $0 as? String }
      .flatMap { $0.data(using: .utf8) }
      .flatMap { $0.JSON }
      .flatMap(Argo.decode)
  }
  
  static func effect(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? { return
    input["effect"]
      .flatMap { $0 as? String }
      .flatMap { $0.data(using: .utf8) }
      .flatMap { $0.JSON }
      .flatMap(Argo.decode)
  }
  
  static func reduced(
    driver: IntegerMutatingApp.Drivers.Either,
    context: IntegerMutatingApp.Model
  ) -> Observable<IntegerMutatingApp.Model> {
    switch driver {
    case .valueToggler(let action): return
      Observable.just((action, context)).reduced()
    case .rxUIApplication(let action): return
      Observable.just((action, context)).reduced()
    case .bugReporter(let action): return
      Observable.just((action, context)).reduced()
    case .shakeDetection(let action): return
      Observable.just((action, context)).reduced()
    }
  }

}

extension IntegerMutatingApp.Drivers {
  enum Either {
    case valueToggler(ValueToggler.Action)
    case rxUIApplication(RxUIApplicationDelegate.Model)
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
  func tupledWithLatestFrom<X, Y>(
    _ x: Observable<X>,
    _ y: Observable<Y>
  ) -> Observable<(E, X, Y)> { return
    tupledWithLatestFrom(x)
      .tupledWithLatestFrom(y)
      .map { ($0.0, $0.1, $1) }
  }
  
  func tupledWithLatestFrom<T>(
    _ input: Observable<T>
  ) -> Observable<(E, T)> { return
    withLatestFrom(input) { ($0, $1 ) }
  }
}

extension ObservableType where E == (MultipeerJSON.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> { return
    flatMap { (event, context) -> Observable<IntegerMutatingApp.Model> in
      switch event {
      case.received(data: let new):
        return new.JSON.flatMap { x in
          let action = curry(IntegerMutatingApp.Model.reduced)
            <^> IntegerMutatingApp.Model.cause(x)
            <*> .some(context)
          let effect = Observable.just
            <^> IntegerMutatingApp.Model.effect(x)
          return action ?? effect
        }
        ?? .never()
      default:
        return .never()
      }
    }
  }
}

extension IntegerMutatingApp.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<IntegerMutatingApp.Model> {
    return curry(IntegerMutatingApp.Model.init)
      <^> json <| "screen"
      <*> .success(RxUIApplicationDelegate.Model.empty)
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
    case .string(let x) where x == "incrementing": return .success(.incrementing)
    case .string(let x) where x == "decrementing": return .success(.decrementing)
    default: return
      .failure(
        .custom("")
      )
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
    case .string(let x) where x == "disabled": return .success(.disabled)
    case .string(let x) where x == "highlighted": return .success(.highlighted)
    default: return
      .failure(
        .typeMismatch(
          expected: "enabled | disabled | highlighted",
          actual: json.description
        )
      )
    }
  }
}

extension BugReporter.Model: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<BugReporter.Model> { return
    curry(BugReporter.Model.init)
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
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model> { return
    curry(ShakeDetection.Model.init)
      <^> json <| "state"
  }
}

extension ShakeDetection.Model.State: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model.State> {
    switch json {
    case .string(let x) where x == "idle": return .success(.idle)
    case .string(let x) where x == "listening": return .success(.listening)
    default: return
      .failure(
        .typeMismatch(
          expected: "String",
          actual: ""
        )
      )
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

extension ObservableType where E == (RxUIApplicationDelegate.Model, IntegerMutatingApp.Model) {
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
