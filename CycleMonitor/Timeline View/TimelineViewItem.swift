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
  enum Output: Equatable {
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
        render(new)
      }
    }
  }
  @IBOutlet private var checkbox: NSButton!
  @IBOutlet private var background: NSBox!
  @IBOutlet private var top: NSBox!
  
  func render(_ input: Model) {
    checkbox.state = NSControl.StateValue(rawValue: input.selected ? 1 : 0)
    background.fillColor = input.background
    top.fillColor = input.top
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    checkbox.target = self
    checkbox.action = #selector(
      didReceiveEventFromCheckbox(button:)
    )
  }
  
  @objc func didReceiveEventFromCheckbox(button: NSButton) {
    model?.selection(
        checkbox.state.rawValue > 0
    )
  }
  
}

extension TimelineViewItem.Model: Equatable {
  static func ==(
    left: TimelineViewItem.Model,
    right: TimelineViewItem.Model
  ) -> Bool {
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
    dirtyRect.fill()
  }
}
