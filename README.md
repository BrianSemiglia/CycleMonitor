# CycleMonitor

A MacOS application for monitoring/editing the state of an application over MultipeerConnectivity.

## Features
- Recording of events and their resulting state (even while disconnected from monitor)
- Playback of states back to device
- Playback of events back to device
- Editing of states via text editor (can be played-back to device as text is entered)
- Saving/opening of sessions
- Generation of tests from selected states in timeline

## Example
Includes a sample app. 1) `pod install`, 2) boot up the monitor and sample app, 3) hit the Record tab and 4) produce events from the iOS application (button-pressing, backgrounding of app, etc.)

## Requirements
- To allow for playback, monitored application must provide serialized state
- Optionally, to allow for playback, Monitored application must be able to deserialize and render received serialized events+states
