//
//  TestService+ArraySender.swift
//  StreamTest
//
//  Created by Labtanza on 9/26/22.
//  https://www.raywenderlich.com/34044359-asyncsequence-asyncstream-tutorial-for-ios

import Foundation
import SwiftUI



struct TestNumberQueueView:View {
    var counter = TestService.shared
    @State var counterVal:Int = 0
    
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                for await value in await counter.numberQueue()  {
                    print("NumberQueue Val: \(value)")
                    counterVal = value
                }
                
            }
    }
}

extension TestService {
    public func numberQueue() -> AsyncStream<Int> {
        let numbersToQueue = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]
        var iterator = AsyncArray(values: numbersToQueue).makeAsyncIterator()
        print("Queue called")
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        
        //() async -> _?
        func unfolding() async -> Int? {
            do {
                if let item = try await iterator.next() {
                    return item
                }
            } catch let error {
                print(error.localizedDescription)
            }
            return nil
            
        }
        
        //optional
        @Sendable func onCancel() -> Void {
            print("confirm counter got canceled")
        }
    }
    
}
