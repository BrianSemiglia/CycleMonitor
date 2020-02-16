//
//  BugReporter.swift
//  Cycle
//
//  Created by Brian Semiglia on 7/20/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import RxSwift
import MessageUI
import Cycle

final class BugReporter: NSObject, MFMailComposeViewControllerDelegate, Drivable {
  struct Model: Equatable {
    enum State: Equatable {
      case idle
      case shouldSend
      case sending(Data)
    }
    var state: State
  }
  enum Action: Equatable {
    case none
    case didSuccessfullySend
  }
  
  let cleanup = DisposeBag()
  let output = BehaviorSubject(value: Action.none)
  var model: Model
  
  init(initial: Model) {
    model = initial
  }
  
    func rendering(model input: Observable<Model>) -> Self {
        input
            .observeOn(MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] new in
                    if let `self` = self {
                      if self.model != new {
                        self.model = new
                        self.render(new)
                      }
                    }
                }
            )
            .disposed(by: cleanup)
        return self
    }
    
    func events() -> Observable<Action> {
        return output.asObservable()
    }
  
  func render(_ input: Model) {
    switch input.state {
    case .sending(let data) where MFMailComposeViewController.canSendMail():
      let x = MFMailComposeViewController()
      x.addAttachmentData(
        data,
        mimeType: "application/json",
        fileName: "bug-report"
      )
      x.mailComposeDelegate = self
      UIApplication.shared.keyWindow?.rootViewController?.present(
        x,
        animated: true
      )
    case .idle:
      if UIApplication.shared.keyWindow?.rootViewController?.presentedViewController?.isKind(of: MFMailComposeViewController.self) == true {
        UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true)
      }
    default:
      break
    }
  }
  
  func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    output.on(.next(.didSuccessfullySend))
  }
}
