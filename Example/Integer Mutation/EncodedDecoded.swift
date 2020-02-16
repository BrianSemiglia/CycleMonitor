//
//  EncodedDecoded.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/15/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation
import Curry
import Argo
import Runes

extension IntegerMutatingApp.Model {
    
    static func cause(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Drivers.Either? {
        input["cause"]
            .flatMap(Argo.decode)
    }
    
    static func context(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
        input["context"]
            .flatMap { $0 as? String }
            .flatMap { $0.data(using: .utf8) }
            .flatMap { $0.JSON }
            .flatMap(Argo.decode)
    }
    
    static func effect(_ input: [AnyHashable: Any]) -> IntegerMutatingApp.Model? {
        input["effect"]
            .flatMap { $0 as? String }
            .flatMap { $0.data(using: .utf8) }
            .flatMap { $0.JSON }
            .flatMap(Argo.decode)
    }
    
}

extension IntegerMutatingApp.Drivers {
    enum Either {
        case valueToggler(ValueToggler.Event)
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

extension Data {
    var JSON: [AnyHashable: Any]? {
        (
            try? JSONSerialization.jsonObject(
                with: self,
                options: JSONSerialization.ReadingOptions(rawValue: 0)
            )
        )
        .flatMap { $0 as? [AnyHashable: Any] }
    }
    var binaryPropertyList: [AnyHashable: Any]? {
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
    func binaryPropertyList() -> Data? {
        try? PropertyListSerialization.data(
            fromPropertyList: self,
            format: .binary,
            options: 0
        )
    }
}

extension IntegerMutatingApp.Model: Argo.Decodable {
    static func decode(_ json: JSON) -> Decoded<IntegerMutatingApp.Model> {
        curry(IntegerMutatingApp.Model.init)
            <^> json <| "screen"
            <*> json <| "motionReporter"
            <*> .success(false)
    }
}

extension ValueToggler.Model: Argo.Decodable {
    static func decode(_ json: JSON) -> Decoded<ValueToggler.Model> {
        curry(ValueToggler.Model.init)
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
        curry(ValueToggler.Model.Button.init)
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
    static func decode(_ json: JSON) -> Decoded<BugReporter.Model> {
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
    static func decode(_ json: JSON) -> Decoded<ShakeDetection.Model> {
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
