# CycleMonitor

A MacOS application for monitoring/editing the state of an application over MultipeerConnectivity. It was written with the intent of being paired with applications written using [Cycle.swift](https://github.com/BrianSemiglia/Cycle.swift/) but is not exclusive to those applications.

![alt tag](readme_images/overview.gif)

## Features
- Recording of events and their resulting state (even while disconnected from monitor)
- Playback of states back to device
- Playback of events back to device
- Saving/opening of sessions
- Generation of tests from selected states in timeline
- Editing of states via text editor (can be played-back to device as text is entered)

![alt tag](readme_images/editing.gif)

## Example
Includes a sample app. To use:
1. Run `pod install`
2. Boot up the monitor and sample app
3. Hit the Record tab
4. Select the intended client from the drop-down
5. Produce events from the iOS application (button-pressing, backgrounding of app, etc.)

The sample app also keeps a running total of the last 25 `Events` to allow for later review should you experience something worth review while offline. To retrieve that timeline:
1. Produce events from the iOS application (button-pressing, backgrounding of app, etc.)
2. Shake the device
3. Send the report to yourself
4. Open the report using `CycleMonitor`

## Usage
### Events
CycleMonitor records state as `Events` over time. Those `Events` have the following schema:

    struct Event {
      var drivers: [Driver]
      var cause: Driver
      var effect: String
      var context: String
      var isApproved = false
      
      struct Driver { // Drivers are event producers
        var label: String
        var action: String
        var id: String
      }
    }

Each `Event` (or `Moment` rather) provides its cause/effect as well as a list of the drivers/event-producers that were being recorded at the time. The moment's active driver/event-producer indicates itself as the cause by providing a non-nil `action`. An `Event`'s context/effect can be conveniently be created using the reflective abilities of `Wrap` (`func wrap<T>(_ object: T) -> [String: Any]?`).
   
### Event/State Broadcast
As events are experienced on the client, they can be encoded as `Event`s, converted to JSON and broadcasted to the monitor. `MultipeerJSON` is provided as a convenience to make those broadcasts and is designed to consume a type of `RxSwift.Observable<[AnyHashable: Any]>`. `MultipeerJSON` buffers outgoing transmissions until a connection is established. `MultipeerJSON` also provides an  `RxSwift.Observable` of responses should you choose to send state back to the device via `CycleMonitor`'s _Effects On Device_ feature.

    let event = CycleMonitor.Event(...)
    let JSON = event.coerced() as [AnyHashable: Any]
    let transmitter = MultipeerJSON()
    let responses: RxSwift.Observable<[AnyHashable: Any]> = transmitter.rendered(
      RxSwift.Observable.just(JSON)
    )

### Event/State Consumption
If your application is designed to maintain and render state seperately, it has the potential to disregard its version of state and instead consume a new state remotely injected. `CycleMonitor` can send states to a client in order to review their rendering. Converting the incoming JSON into your application's `State` is not as easy as the inverse and requires traditional JSON serialization.

### Test Creation
Once the `effect` of a `cause` on a `context` is considered to be correct, that `Event`/`Moment` can be serialized and further tested as development continues. To save `Event`s/`Moment`s, select their checkbox in the timeline and then select `File > Export Tests`. Those files can then be imported into the client's Xcode project and tested. The sample app uses this single (pseudo code) function for all `Event`s/`Moment`s:

    // 1. deserialize all `.moment` files into the application's corresponding Event/State types
    // 2. assert that each `Moment`'s `event` applied to its `context` produces its `effect`
    
This approach only tests the business-logic/state-manipulation portion of the application, not the rendering of the resulting state.
