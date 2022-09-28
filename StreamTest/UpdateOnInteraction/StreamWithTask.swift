//
//  ManagedTaskStream.swift
//  StreamTest
//
//  Created by Labtanza on 9/28/22.
//


import Foundation
import SwiftUI

struct ManagedTask:View {
    var counter = StreamWithTask.shared
    @State var counterVal:Int = 0
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                //Fires constantly.
                for await value in await counter.stream() {
                    print("Stream With Task: \(value)")
                    counterVal = value
                    //Doing something time consuming here does not matther to
                    //the spaming problem
                }
            }
    }
}



actor StreamWithTask {
    static let shared = StreamWithTask()
    
    @MainActor @Published var counter:Int = 0
    @MainActor public func updateCounter(by delta:Int) async {
        counter = counter + delta
    }

    
    public func stream() -> AsyncStream<Int> {
        AsyncStream { continuation in
            let streamTask = Task {
                for await n in $counter.values {
                    continuation.yield(n)
                }
            }

            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
                print("StreamTask Canceled")
            }

        }
    }
    
}







