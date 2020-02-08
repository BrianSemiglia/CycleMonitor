//
//  SourceReflection.swift
//  Integer Mutation
//
//  Created by Brian Semiglia on 2/8/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import Foundation

func sourceCode(_ instance: Any, inset: String = "") -> String {
    let mirror = Mirror(reflecting: instance)

    var result = ""

    result += String(reflecting: mirror.subjectType.self) + "(\n"
    mirror.children.enumerated().forEach { index, tuple in
        guard let label = tuple.label else { return }
        let possibleComma = (mirror.children.count == index + 1 ? "" : ",")
        result += inset + "\t"
        switch Mirror(reflecting: tuple.value).displayStyle {
        case .enum:
            result += "\(label): " + "." + "\(tuple.value)" + possibleComma + "\n"
        case .optional:
            result += "\(label): " + "\(tuple.value)" + possibleComma + "\n"
        case .struct:
            result += "\(label): " + sourceCode(tuple.value, inset: inset + "\t") + possibleComma + "\n"
        case _:
            if type(of: tuple.value) == String.self {
                result += "\(label): " + "\"\(tuple.value)\"" + possibleComma + "\n"
            } else if type(of: tuple.value) == Bool.self || tuple.value as? Int != nil {
                result += "\(label): " + "\(tuple.value)" + possibleComma + "\n"
            } else {
                result += "\(label): "
                    + ".init"
                    + "("
                    + "\(tuple.value)"
                    + possibleComma
                    + "\n"
            }
        }
    }
    result += inset + ")"

    return result
}
