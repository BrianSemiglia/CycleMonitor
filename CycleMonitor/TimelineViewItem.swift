//
//  TimelineViewItem.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa

class TimelineViewItem: NSCollectionViewItem {}

@IBDesignable class BackgroundColoredView: NSView {
  @IBInspectable var backgroundColor: NSColor?
  
  override func awakeFromNib() {
    wantsLayer = true;  // NSView will create a CALayer automatically
    setNeedsDisplay(frame)
  }
  
  override func updateLayer() {
    layer?.backgroundColor = backgroundColor?.cgColor
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    backgroundColor?.setFill()
    NSRectFill(dirtyRect)
  }
}
