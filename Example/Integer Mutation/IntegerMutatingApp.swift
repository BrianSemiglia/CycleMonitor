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
import RxSwiftExt

@UIApplicationMain class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var lens: Any?
    
    /* TODO
        🤔 1. new type that enforces a prefix on a lens that must be returned by CycledLens init to ensure kickoff
        ✅ 2. Debug CycledLens that records Moments and wraps/unwraps inner lenses for convenience
           3. Handle initial values for drivers
        🤔 4. Refactor Lens to use single A (observable). be careful about multi-instances when `getting`. oh right: `set` needs results of `A` which needs to be same instance
        ✅ 5. Threading parameter in driver lens factory
        ✅ 6. Fix duplicate events
           7. Delta highlights for monitor state
    */
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let lens = CycledLens { source in
            MutatingLens<Any, Any, Any>.zip(
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
                source.lens(
                    lifter: { $0.motionReporter },
                    driver: ShakeDetection(initial: .init(state: .listening)),
                    reducer: reportingOnShake
                )
            )
            .map { state, toggle -> UIViewController in
                toggle.0.backgroundColor = .white
                toggle.1.backgroundColor = .lightGray
                toggle.2.backgroundColor = .darkGray
                toggle.3.backgroundColor = .white
                toggle.4.backgroundColor = .lightGray
                toggle.5.backgroundColor = .darkGray

                let stack = UIStackView(arrangedSubviews: [
                    toggle.0,
                    toggle.1,
                    toggle.2,
                    toggle.3,
                    toggle.4,
                    toggle.5
                ])
                stack.axis = .vertical
                stack.distribution = .fillEqually
                let vc = UIViewController()
                vc.view = stack
                return vc
            }
            .momented()
            .multipeered()
            .prefixed(with: IntegerMutatingApp.Model())
//            .bugReported(when: { $0.shouldReport })
        }
        
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

func reportingOnShake(
    state: IntegerMutatingApp.Model,
    event: ShakeDetection.Event
) -> IntegerMutatingApp.Model {
    switch event {
    case .detecting:
        var new = state
        new.shouldReport = true
        return new
    default:
        return state
    }
}

struct IntegerMutatingApp: Equatable {
    struct Model: Equatable {
        var screen = ValueToggler.Model.empty
        var motionReporter = ShakeDetection.Model(state: .listening)
        var shouldReport = false
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
