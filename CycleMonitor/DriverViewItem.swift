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
  @IBOutlet private var background: BackgroundColoredView?
  
  func set(background new: NSColor) {
    background?.backgroundColor = new
  }
  
  func set(labelTop new: String) {
    labelTop?.stringValue = new
  }
  
  func set(labelBottom new: String) {
    labelBottom?.stringValue = new
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
    // Drawing code here.
  }
  
}
