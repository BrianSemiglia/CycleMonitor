//
//  EncodedDecoded.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/15/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import Argo
import Runes
import Curry

extension Moment: Argo.Decodable {
  public static func decode(_ json: JSON) -> Decoded<Moment> {
    
    let drivers = (json <|| "drivers")
        .map(NonEmptyArray<Driver>.init)
        .flatMap(Decoded<NonEmptyArray<Moment>>.fromOptional)
    
    let frame = curry(Moment.Frame.init)
        <^> json <| "cause"
        <*> json <| "effect"
        <*> json <| "context"
        <*> (json <| "isApproved" <|> .success(false))
    
    return curry(Moment.init)
        <^> drivers
        <*> frame
  }
}

extension Moment.Driver: Argo.Decodable {
  public static func decode(_ json: JSON) -> Decoded<Moment.Driver> {
    return curry(Moment.Driver.init)
      <^> json <| "label"
      <*> json <| "action"
      <*> json <| "id"
  }
}

extension TimeLineViewController.Model.Driver: Argo.Decodable {
  static func decode(_ json: JSON) -> Decoded<TimeLineViewController.Model.Driver> {
    return curry(TimeLineViewController.Model.Driver.init)
      <^> json <| "label"
      <*> json <|? "action"
      <*> json <| "id"
  }
}
