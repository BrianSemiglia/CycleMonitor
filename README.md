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

