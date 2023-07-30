//
//  Config.swift
//  Share
//
//  Created by 顾艳华 on 2023/7/9.
//

import Foundation
import SwiftUI
let suiteName = "group.dev.buhe.html.p"

public extension UserDefaults {
    static let shared = UserDefaults(suiteName:  suiteName)!
}
