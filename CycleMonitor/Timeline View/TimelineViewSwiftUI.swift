//
//  TimelineViewSwiftUI.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 2/20/20.
//  Copyright © 2020 Brian Semiglia. All rights reserved.
//

import SwiftUI
import Cycle
import RxSwift

struct TimelineViewSwiftUI: View, DrivableSwiftUI {

    @ObservedObject var model: PublishedObservable<TimeLineViewController.Model>
    var output = PublishSubject<TimeLineViewController.Action>()
    var control: Map! = nil

    struct Map {
        var selectedSegment: Binding<Int>
        var selectedDevice: Binding<Int>
        var pendingState: Binding<String>
    }

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text("Event Producers")
                    List(model.value.drivers) { driver in
                        HStack(spacing: 0) {
                            Color(driver.side).frame(width: 3)
                            VStack {
                                Text(driver.label).padding()
                                Text(driver.action ?? "")
                            }
                            .background(Color(driver.background))
                        }
                    }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: 100,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                VStack {
                    Text("State")
                    TextField(
                        "title",
                        text: Binding(
                            get: {
                                self.model.value.presentedState.string
                            },
                            set: { x in
                                self.output.onNext(.didCreatePendingStateEdit(x))
                            }
                        )
                    )
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(self.model.value.causesEffects.enumerated()) { frame in
                        Color(frame.value.color)
                            .frame(width: 15, height: 25)
                            .onHover { isOver in
                                // find matching frame based on value fails because `frame` is stale value
                                self.output.onNext(
                                    .scrolledToIndex(frame.index)
                                )
                            }
                    }
                }
            }
            HStack(spacing: 20) {
                Spacer(minLength: 20)
                Button(
                    action: { self.output.onNext(.didSelectClearAll) },
                    label: { Text("Clear All") }
                )
                Picker(
                    selection: control.selectedSegment,
                    label: Text("")
                ) {
                    Text("Playing").tag(0)
                    Text("Playing Sending Effects").tag(1)
                    Text("Playing Sending Events").tag(2)
                    Text("Recording").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(model.value.connection != .connected)
                Picker(
                    selection: control.selectedDevice,
                    label: Text("Device")
                ) {
                    ForEach(model.value.devices.enumerated()) { device in
                        Text(device.value.name).tag(device.index)
                    }
                }
                Spacer(minLength: 20)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(10)
    }

    init(model: PublishedObservable<TimeLineViewController.Model>) {
        self.model = model
        let proxy = self // Escaping closure captures mutating 'self' parameter
        self.control = Map(
            selectedSegment: Binding(
                get: {
                    model.value.eventHandlingState.index
                },
                set: { x in
                    if let new = x.eventHandlingState {
                        proxy.output.onNext(
                            .didSelectEventHandling(new)
                        )
                    }
                }
            ),
            selectedDevice: Binding(
                get: { 0 },
                set: { x in
                    proxy.output.onNext(
                        .didSelectItemWith(
                            id: proxy.model.value.devices[x].name
                        )
                    )
                }
            ),
            pendingState: Binding(
                get: {
                    proxy.model.value.presentedState.string
                },
                set: { x in
                    proxy.output.onNext(
                        .didCreatePendingStateEdit(x)
                    )
                }
            )
        )
    }

    func events() -> Observable<TimeLineViewController.Action> {
        output
    }
}

struct Enumerated<T: Identifiable>: Identifiable {
    let value: T
    let index: Int
    let id: AnyHashable
    init(value: T, index: Int) {
        self.value = value
        self.id = value.id
        self.index = index
    }
}

extension Collection where Element: Identifiable {
    func enumerated() -> [Enumerated<Element>] {
        enumerated().map { Enumerated(value: $0.element, index: $0.offset) }
    }
}

struct Foo {
    @Binding var text: String
    let updates: (String) -> Void
    var textField: some View {
        TextField(
            "title",
            text: $text,
            onEditingChanged: { x in
                print(self.text)
                // self.updates(self.text)
            }
        )
    }
}

func binding<T>(value: T, set: @escaping (T) -> Void) -> Binding<T> {
    Binding(
        get: { value },
        set: set
    )
}

func binding<T, U>(
    input: Binding<T>,
    output: PublishSubject<U>,
    transform: @escaping (T) -> U
) -> Binding<T> {
    Binding(
        get: { input.wrappedValue },
        set: { _ in /* output.onNext(transform($0)) */ }
    )
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineViewSwiftUI(
            model: PublishedObservable(
                initial: .preview,
                subsequent: .just(.preview)
            )
        )
    }
}

extension TimeLineViewController.Model {
    static var preview: TimeLineViewController.Model {
        .init(
            drivers: [
                TimeLineViewController.Model.Driver(
                    label: "driver 1",
                    action: "action",
                    id: "driver 1"
                ),
                TimeLineViewController.Model.Driver(
                    label: "driver 2",
                    action: "action",
                    id: "driver 2"
                )
            ],
            causesEffects: [
                TimeLineViewController.Model.CauseEffect(
                    cause: "cause 1",
                    effect: "effect 1",
                    color: .red,
                    id: "1"
                ),
                TimeLineViewController.Model.CauseEffect(
                    cause: "cause 1",
                    effect: "effect 1",
                    color: .red,
                    id: "2"
                ),
                TimeLineViewController.Model.CauseEffect(
                    cause: "cause 1",
                    effect: "effect 1",
                    color: .red,
                    id: "3"
                ),
                TimeLineViewController.Model.CauseEffect(
                    cause: "cause 1",
                    effect: "effect 1",
                    color: .red,
                    id: "4"
                ),
                TimeLineViewController.Model.CauseEffect(
                    cause: "cause 1",
                    effect: "effect 1",
                    color: .red,
                    id: "5"
                )
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                ),
//                TimeLineViewController.Model.CauseEffect(
//                    cause: "cause 1",
//                    effect: "effect 1",
//                    color: .red
//                )
            ],
            presentedState: NSAttributedString(string: "presented state"),
            selected: TimeLineViewController.Model.Selection?.none,
            connection: .idle,
            eventHandlingState: .playing,
            devices: [
                TimeLineViewController.Model.Device(
                    name: "device 1",
                    connection: .idle,
                    id: ""
                )
            ]
        )
    }
}


//    func foo() {
//        let x = self.control.value.selectedSegment
//        let y = self._control
//        let z = self.$control
//        let foo = self.$thingy.selectedSegment
//        let bar = State(selectedSegment: self.model.value.selectedIndex)
//        Picker(selection: bar.$selectedSegment, label: Text("")) {
//            Text("")
//        }
//
//        let n = Foom(value: 6, transform: { _ in 7 })
//        Picker(selection: self.control.value.$selectedSegment, label: Text("")) {
//            Text("")
//        }
//
//        // callbacks = Callback(controlState) { event in ouput.onNext(event) }
//        class Foo<T> {
//            init(binding: Binding<T>) {
//                ObservedObject(initialValue: binding)
//            }
//        }
//    }

//        let x = self.$thingy.selectedSegment.
        // controlState = state.map { ... }
        // textField(binding: controlState)
        // callbacks = Callback(controlState) { event in ouput.onNext(event) }
//        let x = self.$control.value.selecte
