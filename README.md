#  Using Async Streams

Exploration of how to use AsyncStreams to get information out of classes and 
actors by wrapping @Published variables or replaceing them alltogether. 


## Resources

# Related Projects
- https://github.com/carlynorama/LocationExplorer
- https://github.com/carlynorama/NotificationTasks
- https://github.com/carlynorama/AsyncPublisherTests

# AsyncStream Types
- https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md
- https://www.raywenderlich.com/34044359-asyncsequence-asyncstream-tutorial-for-ios

# Fold/Unfold
- Why the name "unfolding"
-  "When is a function a fold or an unfold?" Jeremy Gibbons, Graham Hutton, Thorsten Altenkirch https://doi.org/10.1016/S1571-0661(04)80906-X
- Unfolding — definition — folding, in this order, for avoiding unnecessary variables in logic programs https://link.springer.com/chapter/10.1007/3-540-54444-5_111
- Also these Quora answers: https://www.quora.com/Why-is-an-unfold-function-useful  "Unfolds are useful in the same general way as folds; they allow you to work with recursive data structures without having to write recursive functions. Folds take a function and a seed value, traverse a recursive data structure applying that function to each element, returning a final value. Unfolds take a function and a seed value and build a recursive data structure populated with values. Think of them as folds running in reverse." https://qr.ae/pvibL4

# Motivation

I ran into a behavior with AsyncStream I that did not make sense to me at first, and posted the following to (StackOverflow)

When I have an actor with a published variable, I can "subscribe" to it via an AsyncPublisher and it behaves as expected, updating only when there is a change in value. If I create an AsyncStream with a synchronous context (but with a potential task retention problem) it also behaves as expected.

The weirdness happens when I try to wrap that publisher in an AsyncStream with an asyncronous context. It starts spamming the view with an update per loop it seems, NOT only when there is a change.  

What am I missing about the AsyncStream.init(unfolding:oncancel:) which is causing this behavior?

https://developer.apple.com/documentation/swift/asyncstream/init(unfolding:oncancel:)?  

```
import Foundation
import SwiftUI



actor TestService {
    static let shared = TestService()
    
    @MainActor @Published var counter:Int = 0
    
    @MainActor public func updateCounter(by delta:Int) async {
        counter = counter + delta
    }
    
    public func asyncStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        
        //() async -> _?
        func unfolding() async -> Int? {
            for await n in $counter.values {
                //print("\(location)")
                return n
            }
            return nil
        }
        
        //optional
        @Sendable func onCancel() -> Void {
            print("confirm counter got canceled")
        }
    }
    
    //FWIW, Acknowleding the potential retain cycle problem here.
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
                //TestActorViewA() //<-- uncomment at your own risk. 
                TestActorViewB()
                TestActorViewC()
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
                for await value in await counter.asyncStream() {
                    print("View A Value: \(value)")
                    counterVal = value
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
                //Also only fires on update
                for await value in await counter.syncStream() {
                    print("View C Value: \(value)")
                    counterVal = value
                }
            }
    }
}

```

I semi-answered my own questions:

From what I can tell the "unfolding" style initializer for AsyncStream is not a perfect fit for wrapping an AsyncPublisher. It's a "pull" from within the stream, so from the point of view of the receiver the stream will just keep pushing values since the stream has the infinite well of the AsyncPublisher value to draw from.

It seems like the unfolding style is best used when creating a stream for a finite (but potentially very large) list of items to process. One can force it to work with an @Published by creating a buffer array that is checked repeatedly, and since this solution uses a `didSet`, the variable wouldn't actually need to be @Published anymore. If one has work one wants to do in the actor/class and managing the Task seems more annoying it *might* be worth it to do this way. 


**Buffer -> Stream Example**

```
//inside TestService

//-- Change
    @MainActor @Published var counter:Int = 0 {
        didSet {
            Task { await updateBuffer(newValue:counter) }
        }
    }

//-- New
    var counterBuffer:[Int] = []
    
    func updateBuffer(newValue:Int) async {
        counterBuffer.append(newValue)
    }
    
    func fifoPopValue() -> Int? {
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
                if let value = fifoPopValue() {
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
```

With the view:
```
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
```

**Constant Regular Ping** 

Alternatively if having a value that is a regular ping is something you'd want, changing `asyncStream()` to something like

```
public func alwaysHasSomethingToSayStream() -> AsyncStream<Int> {
        return AsyncStream.init(unfolding: unfolding, onCancel: onCancel)
        
        //() async -> _?
        func unfolding() async -> Int? {
            for await n in $counter.values {
                
                //Adding time consuming code will cause the updates to slow
                //(i.e. to 3 seconds.) If the value is updated faster than 
                //the code is running it will process each value in turn  
                //until it has caught up to the final value.
                //Once it has caught up it will continue push the value.
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
```

**Clean Up on Receiver**

Or you could leave the sender alone and tidy things up on the view end with a diff on the old and new values, but this seems resource intensive.  

```
struct TestActorViewA:View {
    var counter = TestService.shared
    @State var counterVal:Int = 0
    
    
    var body: some View {
        Text("\(counterVal)")
            .task {
              //Constantly getting, not constantly doing anything about it.
                for await value in await counter.asyncStream() {
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
```

This project was a way to share that code and build on it a little further. 
