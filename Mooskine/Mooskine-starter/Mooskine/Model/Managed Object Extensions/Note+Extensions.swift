//
//  Note+Extensions.swift
//  Mooskine
//
//  Created by Márcio Oliveira on 9/8/20.
//  Copyright © 2020 Udacity. All rights reserved.
//

import Foundation
import CoreData

extension Note {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        creationDate = Date()
    }
}
