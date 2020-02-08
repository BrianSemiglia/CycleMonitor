//
//  Integer_Mutation_Tests.swift
//  Integer Mutation Tests
//
//  Created by Brian Semiglia on 9/6/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation
import XCTest

@testable import Integer_Mutation
@testable import RxSwift
@testable import RxTest
@testable import Runes
@testable import Curry

class Integer_MutationTests: XCTestCase {
  
  let cleanup = DisposeBag()
  
  func testMoments() {
    
    let x: Observable<Bool>? = Observable.merge <^>
      Bundle(for: Integer_MutationTests.self)
        .moments
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { $0.binaryPropertyList }
        .flatMap {
          let x = curry(IntegerMutatingApp.Model.reduced)
            <^> IntegerMutatingApp.Model.cause($0)
            <*> IntegerMutatingApp.Model.context($0)
          return curry(==)
            <^> x
            <*> IntegerMutatingApp.Model.effect($0)
        }
    
    let scheduler = TestScheduler(initialClock: 0)
    let observer = scheduler.createObserver(Bool.self)
    x?.subscribe(observer).disposed(by: cleanup)
    scheduler.start()
    
    XCTAssertEqual(
      observer
        .events
        .filter { $0.value.isStopEvent == false }
        .map { $0.value.element ?? false }
      ,
      observer
        .events
        .filter { $0.value.isStopEvent == false }
        .map { _ in true }
    )
  }
  
}

extension Bundle {
  var moments: [URL] {
    urls(
      forResourcesWithExtension: "moment",
      subdirectory: nil
    )
    ?? []
  }
}
