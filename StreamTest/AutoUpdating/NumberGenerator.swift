//
//  NumberGenerator.swift
//  StreamTest
//
//  Created by Labtanza on 9/27/22.
//  https://www.youtube.com/watch?v=UwwKJLrg_0U

import Foundation
import SwiftUI


struct NumberGeneratorView:View {
    @State var currentNumber:Int = 0
    
    var body: some View {
        Text("\(currentNumber)")
            .task {
                for await number in NumberGenerator.numbers {
                    currentNumber = number
                }
            }
    }
}


class NumberGenerator {
    var handler: ((Int)->Void)?
    
    private var timer:Timer?
    
    func startGenerating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [ weak self] _ in
            let number = Int.random(in: 0..<100)
            self?.handler?(number)
        }
    }
    
    func stopGenerating() {
        timer?.invalidate()
        timer = nil
    }
}

extension NumberGenerator {
    static var numbers: AsyncStream<Int> {
        AsyncStream { continuation in
            let generator = NumberGenerator()
            
            generator.handler = { number in
                continuation.yield(number)
            }
            
            //This code is what helps retain the generator
            //if you don't do this the closure retains nothing.
            continuation.onTermination = { @Sendable _ in
                generator.stopGenerating()
                
            }
            
            generator.startGenerating()
        }
    }
}
