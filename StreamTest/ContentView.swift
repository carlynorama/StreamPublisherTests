//
//  ContentView.swift
//  StreamTest
//
//  Created by Labtanza on 9/26/22.
//

import SwiftUI


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
