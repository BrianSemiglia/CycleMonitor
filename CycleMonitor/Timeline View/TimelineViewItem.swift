//
//  TimelineViewItem.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 6/24/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import Runes

class TimelineViewItem: NSCollectionViewItem {
  enum Output {
    case idle
    case selected
    case deselected
  }
  struct Model {
    var background: NSColor
    var top: NSColor
    var bottom: NSColor
    var selected: Bool
    var selection: (Bool) -> Void
  }
  
  var model: Model? {
    didSet {
      if let new = model, new != oldValue {
        print(new.background)
        render(new)
      }
    }
  }
  @IBOutlet private var checkbox: NSButton!
  @IBOutlet private var background: NSBox!
  @IBOutlet private var top: NSBox!
  @IBOutlet private var bottom: NSBox!
  
  func render(_ input: Model) {
    checkbox.state = input.selected ? 1 : 0
    background.fillColor = input.background
    top.fillColor = input.top
    bottom.fillColor = input.bottom
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    checkbox.target = self
    checkbox.action = #selector(didReceiveEventFromCheckbox(button:))
  }
  
  func didReceiveEventFromCheckbox(button: NSButton) {
    model?.selection(checkbox.state > 0)
  }
  
}

extension TimelineViewItem.Model: Equatable {
  static func ==(
    left: TimelineViewItem.Model,
    right: TimelineViewItem.Model
  ) -> Bool { return
    left.selected == right.selected &&
    left.background == right.background &&
    left.top == right.top &&
    left.bottom == right.top
  }
}

@IBDesignable class BackgroundColoredView: NSView {
  
  @IBInspectable var backgroundColor: NSColor? {
    didSet {
      if let new = backgroundColor, new != oldValue {
        setNeedsDisplay(frame)
        display()
      }
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
