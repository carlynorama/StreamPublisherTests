//
//  Array+Sequence.swift
//  StreamTest
//
//  Created by Labtanza on 9/26/22.
//

import Foundation



func pullItems() async {
  // 1
  var iterator = AsyncArray(values: ["george", "ringo", "jouhn", "paul", ""]).makeAsyncIterator()
  
  // 2
  let itemStream = AsyncStream<String> {
    // 3
    do {
      if let item = try await iterator.next() {
        return item
      }
    } catch let error {
      print(error.localizedDescription)
    }
    return nil
  }

  // 4
  for await item in itemStream {
    print(item)
  }
}


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
