//
//  JustAsyncPublisher.swift
//  StreamTest
//
//  Created by Labtanza on 9/28/22.
//

import Foundation
import SwiftUI


struct SimpleAPView:View {
    var counter = SimpleAsyncPublisher.shared
    @State var counterVal:Int = 0
    
    var body: some View {
        Text("\(counterVal)")
            .task {
                //Behaves like one would expect. Fires once per change.
                for await value in await counter.$counter.values {
                    print("Raw Async Publisher Value: \(value)")
                    counterVal = value
                }
            }
    }
}


actor SimpleAsyncPublisher {
    static let shared = SimpleAsyncPublisher()
    
    @MainActor @Published var counter:Int = 0
    
    @MainActor public func updateCounter(by delta:Int) async {
        counter = counter + delta
    }
}
