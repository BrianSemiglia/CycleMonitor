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
import Argo
import Runes
import RxSwiftExt

@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var lens: Any?
    
    /* TODO
        1. new type that enforces a prefix on a lens that must be returned by CycledLens init to ensure kickoff
        2. Debug CycledLens that records Moments and wraps/unwraps inner lenses for convenience
    */
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let lens = CycledLens(
            lens: { source in
                MutatingLens.zip(
                    source.lens(
                        lifter: { $0.screen },
                        driver: ValueToggler(),
                        reducer: mutatingInteger
                    ),
                    source.lens(
                        lifter: { $0.screen },
                        driver: ValueToggler(),
                        reducer: mutatingInteger
                    ),
                    source.lens(
                        lifter: { $0.screen },
                        driver: ValueToggler(),
                        reducer: mutatingInteger
                    ),
                    MutatingLens(
                        value: source,
                        get: { states in
                            ShakeDetection(initial: .init(state: .listening)).rendering(
                                states.map { $0.value.motionReporter }
                            ) { shakes, state in
                                shakes.render(state)
                            }
                        },
                        set: { shake, states in
                            shake
                                .output
                                .tupledWithLatestFrom(states.last(25))
                                .map { event, xs in
                                    switch event {
                                    case .detecting:
                                        var new = xs.last!.value
                                        new.bugReporter.state = xs.map { x in
                                            Moment(
                                                drivers: NonEmptyArray(
                                                    Moment.Driver(
                                                        label: "",
                                                        action: "",
                                                        id: ""
                                                    )
                                                ),
                                                frame: x.summary
                                            )
                                        }
                                        .eventsPlayable
                                        .binaryPropertyList()
                                        .map(BugReporter.Model.State.sending)
                                        ?? .idle
                                        return Meta(
                                            value: new,
                                            summary: xs.last!.summary
                                        )
                                    default:
                                        return Meta(
                                            value: xs.last!.value,
                                            summary: xs.last!.summary
                                        )
                                    }
                                }
                                .labeled("Shakes")
                        }
                    ),
                    source.lens(
                        lifter: { $0.bugReporter },
                        driver: BugReporter(initial: .init(state: .idle)),
                        reducer: { s, _ in s }
                    )
                )
                .map { state, toggle -> UIViewController in
                    toggle.0.backgroundColor = .white
                    toggle.1.backgroundColor = .lightGray
                    toggle.2.backgroundColor = .darkGray
                    let stack = UIStackView(arrangedSubviews: [toggle.0, toggle.1, toggle.2])
                    stack.axis = .vertical
                    stack.distribution = .fillEqually
                    let vc = UIViewController()
                    vc.view = stack
                    return vc
                }
                .multipeered()
                .prefixed(
                    with: .just(
                        Meta(
                            value: IntegerMutatingApp.Model(),
                            summary: Moment.Frame(
                                cause: Moment.Driver(label: "", action: "", id: ""),
                                effect: "",
                                context: "",
                                isApproved: false
                            )
                        )
                    )
                )
            }
        )
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = lens.receiver.0
        self.lens = lens

        return true
    }

}

func mutatingInteger(
    state: IntegerMutatingApp.Model,
    event: ValueToggler.Event
) -> IntegerMutatingApp.Model {
    switch event {
    case .incrementing:
      var x = state
      x.screen.total = Int(x.screen.total).map { $0 + 1 }.map(String.init) ?? ""
      x.screen.increment.state = .enabled
      return x
    case .decrementing:
      var x = state
      x.screen.total = Int(x.screen.total).map { $0 - 1 }.map(String.init) ?? ""
      x.screen.decrement.state = .enabled
      return x
    }
}

struct IntegerMutatingApp: Equatable {
    struct Model: Equatable {
        var screen = ValueToggler.Model.empty
        var bugReporter = BugReporter.Model(state: .idle)
        var motionReporter = ShakeDetection.Model(state: .listening)
    }
    struct Drivers {
        let screen: ValueToggler
        let multipeer: MultipeerJSON
        let bugReporter: BugReporter
        let motionReporter: ShakeDetection
    }
}

// 1. observe requirements
// 2. render requirements: a. String -> Enum -> Driver.Action b. JSON -> App.Model
// 3. test requirements? same as render?
// 4. section sample code into these categories

extension Collection where Iterator.Element == Moment {
  var eventsPlayable: [AnyHashable: Any] {
    ["events": map { $0.coerced() as [AnyHashable: Any] }]
  }
}

extension JSONSerialization {
  static func prettyPrinted(_ input: [AnyHashable: Any]) -> Data? {
    try? JSONSerialization.data(
      withJSONObject: input,
      options: .prettyPrinted
    )
  }
}

extension Data {
  var utf8: String? {
    String(
      data: self,
      encoding: String.Encoding.utf8
    )
  }
}

extension IntegerMutatingApp.Model {
  
  static func cause(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Drivers.Either? {
    input["cause"]
      .flatMap(Argo.decode)
  }
  
  static func context(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
    input["context"]
      .flatMap { $0 as? String }
      .flatMap { $0.data(using: .utf8) }
      .flatMap { $0.JSON }
      .flatMap(Argo.decode)
  }
  
  static func effect(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
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
    case .bugReporter(let action): return
      Observable.just((action, context)).reduced()
    case .shakeDetection(let action): return
      Observable.just((action, context)).reduced()
    }
  }

}

extension IntegerMutatingApp.Drivers {
  enum Either {
    case valueToggler(ValueToggler.Event)
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
  var JSON: [AnyHashable: Any]? {
    (
      try? JSONSerialization.jsonObject(
        with: self,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      )
    )
    .flatMap { $0 as? [AnyHashable: Any] }
  }
  var binaryPropertyList: [AnyHashable: Any]? {
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
  func binaryPropertyList() -> Data? {
    try? PropertyListSerialization.data(
      fromPropertyList: self,
      format: .binary,
      options: 0
    )
  }
}

extension ObservableType where Element == (MultipeerJSON.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> {
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

extension ValueToggler.Event: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<ValueToggler.Event> {
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
  static func decode(_ json: JSON) -> Decoded<BugReporter.Model> {
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
  static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model> {
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

extension ObservableType where Element == (ShakeDetection.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> {
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

extension ObservableType where Element == (BugReporter.Action, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> {
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

extension ObservableType where Element == (ValueToggler.Event, IntegerMutatingApp.Model) {
  func reduced() -> Observable<IntegerMutatingApp.Model> {
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

extension Moment.Frame {
    func setting(cause: Moment.Driver) -> Moment.Frame {
        var new = self
        new.cause = cause
        return new
    }
}

extension Moment.Driver {
    func setting(id: String) -> Moment.Driver {
        var new = self
        new.id = id
        return new
    }
}

extension Observable {
    func labeled(_ input: String) -> Labeled<Observable<Element>> {
        Labeled(value: self, label: input)
    }
}
