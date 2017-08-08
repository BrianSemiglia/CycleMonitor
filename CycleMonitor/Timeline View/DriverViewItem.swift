//
//  DriverViewItem.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa

class DriverViewItem: NSView {

  @IBOutlet private var labelTop: NSTextField?
  @IBOutlet private var labelBottom: NSTextField?
  @IBOutlet private var background: NSBox?
  @IBOutlet private var side: NSBox?
  
  func set(side new: NSColor) {
    side?.fillColor = new
  }
  
  func set(background new: NSColor) {
    background?.fillColor = new
  }
  
  func set(labelTop new: String) {
    labelTop?.stringValue = new
  }
  
  func set(labelBottom new: String) {
    labelBottom?.stringValue = new
  }
  
}
