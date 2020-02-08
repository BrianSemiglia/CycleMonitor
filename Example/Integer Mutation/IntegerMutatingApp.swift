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

//struct CycledLensDebug<Receiver, Value: Equatable> {
//
////    struct Debug<T: Equatable>: Equatable {
////        let value: T
////        let frame: Moment.Frame
////    }
//
//    public let receiver: Receiver
//    private let multipeer: MultipeerJSON
//    private let producer = PublishSubject<Debug<Value>>()
//    private let cleanup = DisposeBag()
//
//    init(
//        lens: (Observable<Debug<Value>>) -> MutatingLens<Observable<Debug<Value>>, Receiver, Observable<Debug<Value>>>
//    ) {
//        let lens = lens(
//            producer
//                .distinctUntilChanged()
//                .share()
//        )
//        .multipeered()
//
//        receiver = lens.get.0
//        multipeer = lens.get.1
//        Observable
//            .merge(lens.set)
//            .observeOn(MainScheduler.asyncInstance)
//            .bind(to: producer)
//            .disposed(by: cleanup)
//    }
//}

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
                        get: { states -> ShakeDetection in
                            ShakeDetection(initial: .init(state: .listening)).rendering(
                                states.map { $0.model.motionReporter }
                            ) { shakes, state in
                                shakes.render(state)
                            }
                        },
                        set: { shake, states in
                            shake.output.tupledWithLatestFrom(states.last(25)).map { event, xs in
                                switch event {
                                case .detecting:
                                    var new = xs.last!.model
                                    new.bugReporter.state = xs.map { x in
                                        Moment(
                                            drivers: NonEmptyArray(
                                                Moment.Driver(
                                                    label: "",
                                                    action: "",
                                                    id: ""
                                                )
                                            ),
                                            frame: x.frame
                                        )
                                    }
                                    .eventsPlayable
                                    .binaryPropertyList()
                                    .map(BugReporter.Model.State.sending)
                                    ?? .idle
                                    return Debug(model: new, frame: xs.last!.frame)
                                default:
                                    return Debug(model: xs.last!.model, frame: xs.last!.frame)
                                }
                            }
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
                        Debug(
                            model: IntegerMutatingApp.Model(),
                            frame: Moment.Frame(
                                cause: Moment.Driver(label: "", action: "", id: ""),
                                effect: "",
                                context: "",
                                isApproved: false
                            )
                        )
                    )
                )
                
                /*
                 
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
                   .rendered(moments.map { $0.coerced() as [AnyHashable: Any] })
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
                 
                 */
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
    static let seed = Model()
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
    func driversFrom(seed: IntegerMutatingApp.Model) -> IntegerMutatingApp.Drivers { return
        Drivers(
            screen: ValueToggler(),
            multipeer: MultipeerJSON(),
            bugReporter: BugReporter(initial: seed.bugReporter),
            motionReporter: ShakeDetection(initial: seed.motionReporter)
        )
    }
//  func effectsOfEventsCapturedAfterRendering(
//    incoming: Observable<Model>,
//    to drivers: Drivers
//  ) -> Observable<Model> {
//    let valueActions = drivers
//      .screen
//      .rendered(incoming.map { $0.screen })
//      .share()
//
//    let applicationActions = drivers
//      .application
//      .eventsCapturedAfterRendering(incoming.map { $0.application })
//      .share()
//
//    let valueEffects = valueActions
//      .tupledWithLatestFrom(incoming)
//      .reduced()
//      .share()
//
//    let applicationEffects = applicationActions
//      .tupledWithLatestFrom(incoming)
//      .reduced()
//      .share()
//
//    let shakeActions = drivers
//      .motionReporter
//      .rendered(incoming.map { $0.motionReporter })
//      .share()
//
//    let shakeEffects = shakeActions
//      .tupledWithLatestFrom(incoming)
//      .reduced()
//      .share()
//
//    let moments = Observable.merge([
//      valueActions
//        .tupledWithLatestFrom(
//          valueEffects,
//          incoming
//            .secondToLast()
//            .unwrap()
//        )
//        .map (Moment.coerced)
//      ,
//      applicationActions
//        .tupledWithLatestFrom(
//          applicationEffects,
//          incoming
//            .secondToLast()
//            .unwrap()
//        )
//        .map { action, effect, context in
//          effect.coerced(
//            sessionAction: wrap(action.session.state)
//              .flatMap { $0 as [AnyHashable: Any] }
//              .flatMap { $0.description }
//              ?? ""
//            ,
//            context: context
//          )
//        }
//      ,
//      shakeActions
//        .tupledWithLatestFrom(
//          shakeEffects,
//          incoming
//            .secondToLast()
//            .unwrap()
//        )
//        .map (Moment.coerced)
//    ])
//    .unwrap()
//    .share()
//
//    let json = drivers
//      .multipeer
//      .rendered(moments.map { $0.coerced() as [AnyHashable: Any] })
//      .tupledWithLatestFrom(incoming)
//      .reduced()
//      .share()
//
//    let reporter = drivers
//      .bugReporter
//      .rendered(
//        incoming
//          .map { $0.bugReporter }
//          .tupledWithLatestFrom(
//            moments
//              .last(25)
//              .map { $0.eventsPlayable }
//          )
//          .map { reporter, moments in
//            switch reporter.state {
//            case .shouldSend:
//              var new = reporter
//              new.state = moments.binaryPropertyList().map(BugReporter.Model.State.sending) ?? .idle
//              return new
//            default:
//              var new = reporter
//              new.state = .idle
//              return new
//            }
//          }
//      )
//      .tupledWithLatestFrom(incoming)
//      .reduced()
//      .share()
//
//    return .merge([
//      valueEffects,
//      applicationEffects,
//      json,
//      reporter,
//      shakeEffects
//    ])
//  }
}

// 1. observe requirements
// 2. render requirements: a. String -> Enum -> Driver.Action b. JSON -> App.Model
// 3. test requirements? same as render?
// 4. section sample code into these categories

extension Collection where Iterator.Element == Moment {
  var eventsPlayable: [AnyHashable: Any] { return
    ["events": map { $0.coerced() as [AnyHashable: Any] }]
  }
}

extension Observable {
  func secondToLast() -> Observable<Element?> { return
    last(2).map { $0.first }
  }
  func lastTwo() -> Observable<(Element?, Element)> { return
    last(2)
    .map {
      switch $0.count {
      case 1: return (nil, $0[0])
      case 2: return ($0[0], $0[1])
      default: abort()
      }
    }
  }
  func last(_ count: Int) -> Observable<[Element]> { return
    scan ([]) { $0 + [$1] }
    .map { $0.suffix(count) }
    .map (Array.init)
  }
}

func wrap(_ input: Any) -> String? {
    wrap(input)
    .map { $0 as [AnyHashable: Any] }
    .map { $0.sorted { a, b in a.key.description > b.key.description } }
    .map { $0.description }
//    .flatMap { JSONSerialization.prettyPrinted($0) }
//    .flatMap { JSONSerialization.prettyPrinted($0)?.utf8 }
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

//extension IntegerMutatingApp.Model {
//  func coerced(
//    sessionAction: String,
//    context: IntegerMutatingApp.Model
//  ) -> Moment? { return
//    curry(Moment.init(drivers:cause:effect:context:))
//      <^> NonEmptyArray(
//        Moment.Driver.shakesWith(),
//        Moment.Driver.valueTogglerWith(),
//        Moment.Driver.sessionWith(action: sessionAction)
//      )
//      <*> Moment.Driver.sessionWith(
//        action: sessionAction
//      )
//      <*> wrap(self)
//        .flatMap (JSONSerialization.prettyPrinted)
//        .flatMap { $0.utf8 }
//      <*> wrap(context)
//        .flatMap (JSONSerialization.prettyPrinted)
//        .flatMap { $0.utf8 }
//  }
//}

//extension Moment {
//  static func coerced(
//    action: ValueToggler.Event,
//    effect: IntegerMutatingApp.Model,
//    context: IntegerMutatingApp.Model
//  ) -> Moment? { return
//    curry(Moment.init(drivers:cause:effect:context:))
//      <^> wrap(action)
//        .map (Moment.Driver.valueTogglerWith)
//        .map {[
//            Moment.Driver.shakesWith(),
//            $0,
//            Moment.Driver.sessionWith()
//        ]}
//        .flatMap (NonEmptyArray.init(possible:))
//      <*> wrap(action)
//        .map(Moment.Driver.valueTogglerWith)
//      <*> wrap(effect)
//          .flatMap (JSONSerialization.prettyPrinted)
//          .flatMap { $0.utf8 }
//      <*> wrap(context)
//          .flatMap (JSONSerialization.prettyPrinted)
//          .flatMap { $0.utf8 }
//  }
//
//  static func coerced(
//    action: ShakeDetection.Action,
//    effect: IntegerMutatingApp.Model,
//    context: IntegerMutatingApp.Model
//  ) -> Moment? { return
//    curry(Moment.init(drivers:cause:effect:context:))
//      <^> wrap(action)
//        .map (Moment.Driver.shakesWith)
//        .map {[
//          $0,
//          Moment.Driver.valueTogglerWith(),
//          Moment.Driver.sessionWith()
//        ]}
//        .flatMap (NonEmptyArray.init(possible:))
//      <*> wrap(action)
//        .map(Moment.Driver.shakesWith)
//      <*> wrap(effect)
//        .flatMap (JSONSerialization.prettyPrinted)
//        .flatMap { $0.utf8 }
//      <*> wrap(context)
//        .flatMap (JSONSerialization.prettyPrinted)
//        .flatMap { $0.utf8 }
//  }
//}

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
//    case .rxUIApplication(let action): return
//      Observable.just((action, context)).reduced()
    case .bugReporter(let action): return
      Observable.just((action, context)).reduced()
    case .shakeDetection(let action): return
      Observable.just((action, context)).reduced()
    }
  }

}

//class RxUIApplicationDelegate {
//    struct Model {}
//}

extension IntegerMutatingApp.Drivers {
  enum Either {
    case valueToggler(ValueToggler.Event)
//    case rxUIApplication(RxUIApplicationDelegate.Model)
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
  func pacedBy(delay: Double) -> Observable<Element> { return
    map {
      Observable
        .empty()
        .delay(
          .milliseconds(Int(delay * 1000)),
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
  ) -> Observable<(Element, X, Y)> { return
    tupledWithLatestFrom(x)
      .tupledWithLatestFrom(y)
      .map { ($0.0, $0.1, $1) }
  }
  
  func tupledWithLatestFrom<T>(
    _ input: Observable<T>
  ) -> Observable<(Element, T)> { return
    withLatestFrom(input) { ($0, $1 ) }
  }
}

extension ObservableType where Element == (MultipeerJSON.Action, IntegerMutatingApp.Model) {
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
//      <*> .success(RxUIApplicationDelegate.Model.empty)
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

//func reduced(
//    before: Debug<IntegerMutatingApp.Model>,
//    event: ShakeDetection.Action
//) -> IntegerMutatingApp.Model {
//    switch event {
//    case .detecting:
//        var new = before.model
//        new.bugReporter.state = .sending(<#T##Data#>)
//        return new
//    default:
//        return before.model
//    }
//}

extension ObservableType where Element == (ShakeDetection.Action, IntegerMutatingApp.Model) {
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

extension ObservableType where Element == (BugReporter.Action, IntegerMutatingApp.Model) {
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

extension ObservableType where Element == (ValueToggler.Event, IntegerMutatingApp.Model) {
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

//extension ObservableType where Element == (RxUIApplicationDelegate.Model, IntegerMutatingApp.Model) {
//  func reduced() -> Observable<IntegerMutatingApp.Model> { return
//    map { event, global in
//      var new = global
//      new.application.shouldLaunch = true
//      if case .pre(.active(.some)) = event.session.state {
//        new.screen.total = "55"
//      }
//      return new
//    }
//  }
//}

public protocol Drivable: NSObject {
    associatedtype Model
    associatedtype Event
    func render(_ input: Model)
    func events() -> Observable<Event>
}

extension Observable {
    public func lens<Driver: Drivable>(
        driver: Driver,
        reducer: @escaping (Element, Driver.Event) -> Element
    ) -> MutatingLens<Observable<Element>, Driver, Observable<Element>> where Element == Driver.Model {
        lens(
            get: { (states: Observable<Element>) -> Driver in
                driver.rendering(states) { driver, state in
                    driver.render(state)
                }
            },
            set: { toggler, state -> Observable<Element> in
                toggler
                    .events()
                    .tupledWithLatestFrom(state)
                    .map { ($0.1, $0.0) }
                    .map(reducer)
            }
        )
    }
    
    func lens<T, Driver: Drivable>(
        lifter: @escaping (T) -> Driver.Model, // Need to figure out getting subset from source -> MutatingLens wants same type on incoming stream
        driver: Driver,
        reducer: @escaping (Element, Driver.Event) -> T
    )
    -> MutatingLens<Observable<Element>, Driver, Observable<Element>>
        where Element == Debug<T> {
        lens(
            get: { (state: Observable<Element>) -> Driver in
                driver.rendering(state.map { $0.model }.map(lifter)) { driver, state in
                    driver.render(state)
                }
            },
            set: { driver, state -> Observable<Element> in
                driver
                    .events()
                    .tupledWithLatestFrom(state.map { $0 })
                    .map { (old: $0.1, event: $0.0, new: reducer($0.1, $0.0)) }
                    .map {
                        Debug(
                            model: $0.new,
                            frame: Moment.Frame(
                                cause: Moment.Driver(
                                    label: "\(type(of: driver))",
                                    action: "\($0.event)",
                                    id: ""
                                ),
                                effect: sourceCode($0.new),
                                context: sourceCode($0.old.model),
                                isApproved: false
                            )
                        )
                    }
            }
        )
    }
    
    func lens<T, Driver: Drivable>(
        lifter: @escaping (T) -> Driver.Model, // Need to figure out getting subset from source -> MutatingLens wants same type on incoming stream
        driver: Driver,
        reducer: @escaping (T, Driver.Event) -> T
    )
    -> MutatingLens<
        Observable<Element>,
        Driver,
        Observable<Element>
    > where Element == Debug<T> {
        lens(
            get: { state in
                driver.rendering(state.map { $0.model }.map(lifter)) { driver, state in
                    driver.render(state)
                }
            },
            set: { driver, state  in
                driver
                    .events()
                    .tupledWithLatestFrom(state)
                    .map { (old: $0.1, event: $0.0, new: reducer($0.1.model, $0.0)) }
                    .map {
                        Debug(
                            model: $0.new,
                            frame: Moment.Frame(
                                cause: Moment.Driver(
                                    label: "\(type(of: driver))",
                                    action: "\($0.event)",
                                    id: ""
                                ),
                                effect: sourceCode($0.new),
                                context: sourceCode($0.old.model),
                                isApproved: false
                            )
                        )
                    }
            }
        )
    }
}

extension Collection {
    func tagged<T>() -> [Observable<(tag: Int, element: T)>] where Element == Observable<T> {
        enumerated().map { indexed in
            indexed.element.map { x in (indexed.offset, x) }
        }
    }
}

extension MutatingLens {
    func multipeered<T>(
        reducer: @escaping (T, Moment.Frame) -> T = { t, m in t }
    ) -> MutatingLens<A, (B, MultipeerJSON), Observable<Debug<T>>>
        where A == Observable<Debug<T>>, C == Observable<Debug<T>> {
        
        let moments = Observable
            .merge(self.set.tagged())
            .map { ($0.tag, $0.1.frame) }
            .map { states in
                Moment(
                    drivers: NonEmptyArray(
                        possible: self.set.enumerated().map { x in
                            Moment.Driver(
                                label: "\(type(of: self.get))", // label is coming from combined lens (eg UIViewController). need inner lens labels
                                action: x.offset == states.0 ? states.1.cause.action : "", //
                                id: String(x.offset)
                            )
                        }
                    )!,
                    frame: states.1.setting(
                        cause: states.1.cause.setting(
                            id: String(states.0)
                        )
                    )
                )
            }
        
            return MutatingLens<A, (B, MultipeerJSON), Observable<Debug<T>>>(
                value: value,
                get: { values in (
                    self.get,
                    MultipeerJSON().rendering(moments) { multipeer, state in
                        multipeer.render(state.coerced() as [AnyHashable: Any])
                    }
                )},
                set: { _, _ in self.set }
            )
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

func sourceCode(_ instance: Any, inset: String = "") -> String {
    let mirror = Mirror(reflecting: instance)

    var result = ""

    result += String(reflecting: mirror.subjectType.self) + "(\n"
    mirror.children.enumerated().forEach { index, tuple in
        guard let label = tuple.label else { return }
        let possibleComma = (mirror.children.count == index + 1 ? "" : ",")
        result += inset + "\t"
        switch Mirror(reflecting: tuple.value).displayStyle {
        case .enum:
            result += "\(label): " + "." + "\(tuple.value)" + possibleComma + "\n"
        case .optional:
            result += "\(label): " + "\(tuple.value)" + possibleComma + "\n"
        case .struct:
            result += "\(label): " + sourceCode(tuple.value, inset: inset + "\t") + possibleComma + "\n"
        case _:
            if type(of: tuple.value) == String.self {
                result += "\(label): " + "\"\(tuple.value)\"" + possibleComma + "\n"
            } else if type(of: tuple.value) == Bool.self || tuple.value as? Int != nil {
                result += "\(label): " + "\(tuple.value)" + possibleComma + "\n"
            } else {
                result += "\(label): "
                    + ".init"
                    + "("
                    + "\(tuple.value)"
                    + possibleComma
                    + "\n"
            }
        }
    }
    result += inset + ")"

    return result
}
