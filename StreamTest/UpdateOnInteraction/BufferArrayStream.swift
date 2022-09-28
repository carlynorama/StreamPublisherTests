//
//  BufferedCounter.swift
//  StreamTest
//
//  Created by Labtanza on 9/28/22.
//

import Foundation
import SwiftUI


struct BufferStreamView:View {
    var counter = BufferArrayStream.shared
    @State var counterVal:Int = 0
    
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                for await value in await counter.bufferStream() {
                    print("Buffer Array Stream: \(value)")
                    counterVal = value
                }
            }.onAppear() {
                counterVal = counter.counter
                Task { await counter.startUp() }
            }
    }
}


//In this example the stream consumes the buffer, so only one per actor.
actor BufferArrayStream {
    static var shared = BufferArrayStream()
    
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
    
    func popValue() async -> Int? {
        guard !counterBuffer.isEmpty else {
            return nil
        }
        return counterBuffer.removeFirst()
    }
    
    var isActive = true
    
    func startUp() async {
        await updateBuffer(newValue: counter)
    }
    
    //TODO: Confirm
    //will end the while loops for all bufferStream() created AsyncStreams
    public func endBufferStreams() async {
        isActive = false
    }
    
    public func bufferStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        //() async -> _?
        func unfolding() async -> Int? {
            while isActive {
                if let value = await popValue() {
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
            print("confirm buffer array stream got canceled")
        }
    }
    
    
}
