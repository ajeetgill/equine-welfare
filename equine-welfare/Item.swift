//
//  Item.swift
//  equine-welfare
//
//  Created by Ajeet Gill on 19/02/25.
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
