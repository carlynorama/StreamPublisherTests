#  Using Async Streams

Exploration of how to use AsyncStreams to get information out of classes and 
actors by wrapping @Published variables or replacing them all together. 


## TL;DR

Best way easy to wrap an @Published in a Stream:

```
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
```

## Contents


Working With AsyncPublisher:
- `JustAsyncPublisher` - Standard for-await AsyncPublisher use case
- `StreamWithTask` - AsyncStream that uses a continuation but cancels its own task *recommended*
- `SloppyStream` - 2 examples AsyncStreams that uses the unfolding init, badly. Not a good fit for this task.
- `BufferArrayStream` - Trying to rate limit the well of values from the publisher by using a buffer array. This is not a recommended solution, but it "works." 

Stand Alone AsyncStreams: 
- `NumberGenerator` - AsyncStream that kicks out random numbers based on a timer
- `NumberQueue` - AsyncStream that kicks out the values in an array based on a timer



## Resources

# Related Projects
- https://github.com/carlynorama/LocationExplorer
- https://github.com/carlynorama/NotificationTasks
- https://github.com/carlynorama/AsyncPublisherTests

# AsyncStream Types
- https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md
- https://www.raywenderlich.com/34044359-asyncsequence-asyncstream-tutorial-for-ios
- Meet the new alternative to Combine's Publisher! (it's called AsyncStream) https://www.youtube.com/watch?v=UwwKJLrg_0U 
- https://stackoverflow.com/questions/73860731/asyncstream-spams-view-where-asyncpublisher-does-not/

# Fold/Unfold
- Why the name "unfolding"
-  "When is a function a fold or an unfold?" Jeremy Gibbons, Graham Hutton, Thorsten Altenkirch https://doi.org/10.1016/S1571-0661(04)80906-X
- Unfolding — definition — folding, in this order, for avoiding unnecessary variables in logic programs https://link.springer.com/chapter/10.1007/3-540-54444-5_111
- Also these Quora answers: https://www.quora.com/Why-is-an-unfold-function-useful  "Unfolds are useful in the same general way as folds; they allow you to work with recursive data structures without having to write recursive functions. Folds take a function and a seed value, traverse a recursive data structure applying that function to each element, returning a final value. Unfolds take a function and a seed value and build a recursive data structure populated with values. Think of them as folds running in reverse." https://qr.ae/pvibL4



# Motivation

I ran into a behavior with AsyncStream I that did not make sense to me at first.

I had an actor with a published variable which I could can "subscribe" to via an AsyncPublisher and it behaved as expected, updating only when there is a change in value. If I created an AsyncStream with a synchronous context (but with a potential task retention problem) it also behaved as expected.

The weirdness happened when I wrapped that publisher in an AsyncStream with an asynchronous context. It started spamming the view with an update per loop it seems, NOT only when there was a change.  

I created this project to help figure out what I was missing about  (AsyncStream.init(unfolding:oncancel:))[https://developer.apple.com/documentation/swift/asyncstream/init(unfolding:oncancel:)?]


## Initial Code

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
    
    //has a task retain problem. 
   public func syncStream() -> AsyncStream<Int> {
        AsyncStream { continuation in
            Task {
                for await n in $counter.values {
                    //do hard work to transform n 
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

## Best Answer for Simply Wrapping Publisher

The real solution to wrapping a publisher appears to be to stick to the synchronous context initializer and have it cancel it's own task: 

```
public func stream() -> AsyncStream<Int> {
        AsyncStream { continuation in
            let streamTask = Task {
                for await n in $counter.values {
                    //do hard work to transform n 
                    continuation.yield(n)
                }
            }

            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
                print("StreamTask Canceled")
            }

        }
    }
```

## Use case for the "Unfolding" init style 

From what I can tell the "unfolding" style initializer for AsyncStream is simply not a fit for wrapping an AsyncPublisher. The "unfolding" function will "pull" at the published value from within the stream, so the stream will just keep pushing values from that infinite well.

It seems like the "unfolding" style initializer is best used when processing a finite (but potentially very large) list of items, or when generating ones values from scratch... something like:  

```
struct NumberQueuer {
    let numbers:[Int]
    
    public func queueStream() -> AsyncStream<Int> {
        var iterator = AsyncArray(values: numbers).makeAsyncIterator()
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
            print("confirm NumberQueue got canceled")
        }
    }
    
}

public struct AsyncArray<Element>: AsyncSequence, AsyncIteratorProtocol {
    
    let values:[Element]
    let delay:TimeInterval
    
    var currentIndex = -1
    
    public init(values: [Element], delay:TimeInterval = 1) {
        self.values = values
        self.delay = delay
    }
    
    public mutating func next() async throws -> Element? {
        currentIndex += 1
        guard currentIndex < values.count else {
            return nil
        }
        try await Task.sleep(nanoseconds: UInt64(delay * 1E09))
        return values[currentIndex]
    }
    
    public func makeAsyncIterator() -> AsyncArray {
        self
    }
}

```

One can force the unfolding type to work with an @Published by creating a buffer array that is checked repeatedly. The variable wouldn't actually need to be @Published anymore. This approach has a lot of problems but it can be made to work. See `BufferArrayStream` 





