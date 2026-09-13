//
//  Item.swift
//  GestionTutorial
//
//  Created by Marcos on 13/09/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
