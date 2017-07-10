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
  
  @IBInspectable var backgroundColor: NSColor? {
    didSet {
      setNeedsDisplay(frame)
      display()
    }
  }
  
  override func awakeFromNib() {
    wantsLayer = true;  // NSView will create a CALayer automatically
    setNeedsDisplay(frame)
    display()
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
