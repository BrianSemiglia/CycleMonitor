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
  let manager = CMMotionManager()
  
  init(initial: Model) {
    model = initial
    manager
      .rx
      .accelerometerData
      .map {(
        $0.acceleration.x,
        $0.acceleration.y,
        $0.acceleration.z
      )}
      .scan([(Double, Double, Double)]()) { $0 + [$1] }
      .map { $0.suffix(2) }
      .map (Array.init)
      .filter {
        if $0.count > 1 { return
          fabs($0[0].0) > (fabs($0[1].0) + 0.75) ||
          fabs($0[0].1) > (fabs($0[1].1) + 0.75) ||
          fabs($0[0].2) > (fabs($0[1].2) + 0.75)
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
      manager.stopAccelerometerUpdates()
    case .listening:
      manager.startAccelerometerUpdates()
    }
  }
}
