//
//  ContentView.swift
//  StreamTest
//
//  Created by Labtanza on 9/26/22.
//

import SwiftUI


struct IncrementButton:View {
    var counter = SimpleAsyncPublisher.shared
    var sloppyStream = SloppyStream.shared
    var bufferStream = BufferArrayStream.shared
    var managedTaskStream = StreamWithTask.shared
    
    
    var body: some View {
        Button("increment counter") {
            Task { await counter.updateCounter(by: 2) }
            Task { await sloppyStream.updateCounter(by: 2) }
            Task { await bufferStream.updateCounter(by: 2) }
            Task { await managedTaskStream.updateCounter(by: 2) }
         }
        }
    }



struct ContentView: View {
   
    
    @State var showHide = true
    
    var body: some View {
        VStack {
            Button("Show/Hide") { showHide.toggle() }
            if showHide {
                IncrementButton()
                
                HStack {
                    SloppyStreamView()
                    SimpleAPView()
                    ManagedTask()
                    BufferStreamView()
                }
            }
            HStack {
                NumberGeneratorView()
                NumberQueueView()
            }
        }
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
