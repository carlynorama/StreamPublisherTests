//
//  TestActor.swift
//  LocationExplorer
//
//  Created by Labtanza on 9/26/22.
//

import Foundation
import SwiftUI


struct SloppyStreamView:View {
    var counter = SloppyStream.shared
    @State var counterVal:Int = 0
    
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                //Fires constantly.
                for await value in await counter.constantStream() {
                    if value != counterVal {
                        print("View A Value: \(value)")
                        counterVal = value
                    }
                    //Expensive work or explicit rate limiter.
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        
                    }
                }
            }
    }
}









actor SloppyStream {
    static let shared = SloppyStream()
    
    @MainActor @Published var counter:Int = 0
    
    @MainActor public func updateCounter(by delta:Int) async {
        counter = counter + delta
    }
    
    

    public func alwaysHasSomethingToSayStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        
        //() async -> _?
        func unfolding() async -> Int? {
            for await n in $counter.values {
                
                //Adding time consuming code will cause the updates to slow
                //(i.e. to 3 seconds.) If the value is updated faster than the
                //code is runing it will process each value in turn until it
                //has caught up to the final value.
                //Once it has caught up it will contine push the value.
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    
                }
                return n
            }
            return nil
        }
        
        //optional
        @Sendable func onCancel() -> Void {
            print("confirm counter got canceled")
        }
    }
    
    public func constantStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        
        //() async -> _?
        func unfolding() async -> Int? {
            for await n in $counter.values {
                return n
            }
            return nil
        }
        
        //optional
        @Sendable func onCancel() -> Void {
            print("confirm counter got canceled")
        }
    }
    
}






