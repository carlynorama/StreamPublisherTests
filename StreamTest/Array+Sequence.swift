//
//  Array+Sequence.swift
//  StreamTest
//
//  Created by Labtanza on 9/26/22.

import Foundation
import SwiftUI



public struct AsyncArray<Element>: AsyncSequence, AsyncIteratorProtocol {
    
    let values:[Element]
    let delay:TimeInterval
    
    var currentIndex = -1
    
    public init(values: [Element], delay:TimeInterval = 1) {
        self.values = values
        self.delay = delay
    }
    
    public mutating func next() async throws -> Element? {
        currentIndex += 1
        guard currentIndex < values.count else {
            return nil
        }
        try await Task.sleep(nanoseconds: UInt64(delay * 1E09))
        return values[currentIndex]
    }
    
    public func makeAsyncIterator() -> AsyncArray {
        self
    }
}
