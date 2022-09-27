//
//  TestActor.swift
//  LocationExplorer
//
//  Created by Labtanza on 9/26/22.
//

import Foundation
import SwiftUI



actor TestService {
    static let shared = TestService()
    
    @MainActor @Published var counter:Int = 0 {
        didSet {
            Task { await updateBuffer(newValue:counter) }
        }
    }
    
    @MainActor public func updateCounter(by delta:Int) async {
        counter = counter + delta
    }
    
    var counterBuffer:[Int] = []
    
    func updateBuffer(newValue:Int) async {
        counterBuffer.append(newValue)
    }
    
    func popValue() -> Int? {
        guard !counterBuffer.isEmpty else {
            return nil
        }
        return counterBuffer.removeFirst()
    }
    
    var isActive = true
    
    public func bufferStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        //() async -> _?
        func unfolding() async -> Int? {
            while isActive {
                if let value = popValue() {
                    return value
                }
                do {
                    try await Task.sleep(nanoseconds: 1_000_000)
                } catch {
                    
                }
                
            }
            return nil
        }
        
        //optional
        @Sendable func onCancel() -> Void {
            print("confirm counter got canceled")
        }
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
    
    //FWIW, Acknowleding the the retain cycle problem
    public func syncStream() -> AsyncStream<Int> {
        AsyncStream { continuation in
            Task {
                for await n in $counter.values {
                    continuation.yield(n)
                }
            }
        }
    }
    
}

struct ContentView: View {
    var body: some View {
        VStack {
            TestActorButton()
            HStack {
                TestActorViewA()
                TestActorViewB()
                TestActorViewC()
                TestActorViewD()
            }
        }
        .padding()
    }
}


struct TestActorButton:View {
    var counter = TestService.shared
    
    
    var body: some View {
        Button("increment counter") {
            Task { await counter.updateCounter(by: 2) }
        }
    }
}


struct TestActorViewA:View {
    var counter = TestService.shared
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

struct TestActorViewB:View {
    var counter = TestService.shared
    @State var counterVal:Int = 0
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                //Behaves like one would expect. Fires once per change.
                for await value in await counter.$counter.values {
                    print("View B Value: \(value)")
                    counterVal = value
                }
            }
    }
}

struct TestActorViewC:View {
    var counter = TestService.shared
    @State var counterVal:Int = 0
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                //Fires constantly.
                for await value in await counter.syncStream() {
                    print("View C Value: \(value)")
                    counterVal = value
                    //Doing something time consuming here does not matther to
                    //the spaming problem
                }
            }
    }
}


struct TestActorViewD:View {
    var counter = TestService.shared
    @State var counterVal:Int = 0
    
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                for await value in await counter.bufferStream() {
                    print("View D Value: \(value)")
                    counterVal = value
                }
            }
    }
}
