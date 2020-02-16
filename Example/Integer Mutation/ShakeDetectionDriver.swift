//
//  ShakeDetectionDriver.swift
//  Cycle
//
//  Created by Brian Semiglia on 7/21/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import RxSwift
import CoreMotion
import RxCoreMotion
import Cycle

final class ShakeDetection: NSObject, Drivable {
  struct Model: Equatable {
    enum State: Equatable {
      case idle
      case listening
    }
    var state: State
  }
  enum Action: Equatable {
    case none
    case detecting
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var model: Model
  let motions = CMMotionManager()
  
  init(initial: Model) {
    model = initial
    super.init()
    motions
      .rx
      .accelerometerData
      .map { $0.acceleration }
      .scan([]) { $0 + [$1] }
      .map { $0.suffix(2) }
      .map (Array.init)
      .filter { _ in self.model.state == ShakeDetection.Model.State.listening }
      .filter {
        if $0.count > 1 { return
          fabs($0[0].x) > (fabs($0[1].x) + 0.65) ||
          fabs($0[0].y) > (fabs($0[1].y) + 0.65) ||
          fabs($0[0].z) > (fabs($0[1].z) + 0.65)
        } else {
          return false
        }
      }
      .throttle(
        .milliseconds(500),
        scheduler: MainScheduler.asyncInstance
      )
      .subscribe { [weak self] x in
        self?.output.on(.next(.detecting))
      }
      .disposed(by: cleanup)
    render(initial)
  }
      
    func events() -> Observable<ShakeDetection.Action> {
        output.asObservable()
    }
  
  func render(_ input: Model) {
//    switch input.state {
//    case .idle:
//      motions.stopAccelerometerUpdates()
//    case .listening:
//      motions.startAccelerometerUpdates()
//    }
  }
}
