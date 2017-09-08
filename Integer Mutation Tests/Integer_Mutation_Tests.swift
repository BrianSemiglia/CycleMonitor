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
@testable import Runes
@testable import Curry

class Integer_MutationTests: XCTestCase {
  
  func testMoments() {
    
    let x: [Observable<Bool>]? = Bundle(for: Integer_MutationTests.self)
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
    
    x?.forEach {
      $0.subscribe(onNext: { x in
        print(x)
      })
    }
  }
  
}

func ==(_ stream: Observable<IntegerMutatingApp.Model>, _ model: IntegerMutatingApp.Model) -> Observable<Bool> {
  return stream.map { $0 == model }
}

extension Bundle {
  var moments: [URL] { return
    urls(
      forResourcesWithExtension: "moment",
      subdirectory: nil
      )
      ?? []
  }
}
