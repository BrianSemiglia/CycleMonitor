//
//  Terminator.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/16/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import Cycle
import RxSwift

final class TerminationDriver: NSObject, Drivable {
  struct Model: Equatable {
    var shouldTerminate: Bool
  }
  
  enum Action {
    case none
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)

  var model: Model {
    didSet {
      if model != oldValue {
        render(model)
      }
    }
  }
  
  init(model: Model) {
    self.model = model
    super.init()
    render(model)
  }
    
  func render(_ input: Model) {
    if input.shouldTerminate {
      NSApplication
        .shared
        .terminate(nil)
    }
  }
    
    func events() -> Observable<Action> {
        .never()
    }
}
