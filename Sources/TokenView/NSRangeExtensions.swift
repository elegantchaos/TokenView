// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Developer on 27/08/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension NSRange {
    func clipped(to length: Int) -> NSRange {
        var newLocation = self.location
        var newLength = self.length
        if newLocation >= length {
            newLocation = length - 1
        }
        if newLocation + newLength >= length {
            newLength = length - newLocation
        }
        return NSRange(location: newLocation, length: newLength)
    }
    
    func clipped(to string: String) -> NSRange {
        return clipped(to: string.count)
    }
    
    func clipped(to string: NSAttributedString) -> NSRange {
        return clipped(to: string.length)
    }
}
