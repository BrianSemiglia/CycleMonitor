//
//  ViewController.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa

class ViewController:
  NSViewController,
  NSCollectionViewDataSource,
  NSCollectionViewDelegateFlowLayout {
  
  struct Model {
    let drivers: [(name: String, event: String, appearance: NSColor)]
    let causesEffects: [(state: String, event: String)]
  }

  @IBOutlet var drivers: NSCollectionView!
  @IBOutlet var timeline: NSCollectionView!
  var model = Model(drivers: [(name: "name", event: "event", .red)], causesEffects: [(state: "state", event: "event")])
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
  }
  
  public func collectionView(
    _ collectionView: NSCollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    if collectionView === drivers {
      return 0
    } else {
      return model.causesEffects.count
    }
  }
  
  func collectionView(
    _ caller: NSCollectionView,
    itemForRepresentedObjectAt path: IndexPath
  ) -> NSCollectionViewItem {
    
//    if collectionView === drivers {
//      return model.drivers.count
//    } else {
      caller.register(
        NSNib(nibNamed: "TimelineViewItem", bundle: nil),
        forItemWithIdentifier: "TimelineViewItem"
      )
      let x = caller.makeItem(
        withIdentifier: "TimelineViewItem",
        for: path
      )
    return x
//    }

  }
    
  func collectionView(
    _ collectionView: NSCollectionView,
    layout collectionViewLayout: NSCollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> NSSize {
    return NSSize(
      width: 44.0,
      height: 138.0
    )
  }

}

