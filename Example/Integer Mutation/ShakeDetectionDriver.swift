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

class ShakeDetection {
  struct Model {
    enum State {
      case idle
      case listening
    }
    var state: State
  }
  enum Action {
    case none
    case detecting
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var model: Model
  let motions = CMMotionManager()
  
  init(initial: Model) {
    model = initial
    motions
      .rx
      .accelerometerData
      .map { $0.acceleration }
      .scan([]) { $0 + [$1] }
      .map { $0.suffix(2) }
      .map (Array.init)
      .filter {
        if $0.count > 1 { return
          fabs($0[0].x) > (fabs($0[1].x) + 0.75) ||
          fabs($0[0].y) > (fabs($0[1].y) + 0.75) ||
          fabs($0[0].z) > (fabs($0[1].z) + 0.75)
        } else {
          return false
        }
      }
      .throttle(
        0.5,
        scheduler: MainScheduler.asyncInstance
      )
      .subscribe { [weak self] x in
        self?.output.on(.next(.detecting))
      }
      .disposed(by: cleanup)
    render(initial)
  }
  
  func rendered(_ input: Observable<Model>) -> Observable<Action> {
    input.subscribe {
      if let new = $0.element {
        self.render(new)
      }
    }.disposed(by: cleanup)
    return output
  }
  
  func render(_ input: Model) {
    switch input.state {
    case .idle:
      motions.stopAccelerometerUpdates()
    case .listening:
      motions.startAccelerometerUpdates()
    }
  }
}
