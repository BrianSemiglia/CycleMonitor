//
//  MultipeerJSON.swift
//  CycleMonitor
//
//  Created by Brian Semiglia on 7/3/17.
//  Copyright © 2017 Brian Semiglia. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import RxSwift
import Curry
import Runes

final class MultipeerJSON:
      NSObject,
      MCNearbyServiceBrowserDelegate,
      MCSessionDelegate {

  enum Model {
    case idle
    case connecting(peer: Data)
    case sending(data: [AnyHashable: Any], peer: Data)
  }
  
  enum Action {
    case launching
    case connecting(Data)
    case connected(Data)
    case disconnected(Data)
    case received(data: Data, peer: Data)
    case didFind(name: String, peer: Data)
  }
  
  private let cleanup = DisposeBag()
  public let output: BehaviorSubject<Action>
  
  var session: MCSession?
  let mine: MCPeerID
  let browser: MCNearbyServiceBrowser
  
  override init() {
    output = BehaviorSubject<Action>(value: .launching)
    mine = MCPeerID(
      displayName: Host.current().localizedName ?? "Unknown"
    )
    browser = MCNearbyServiceBrowser(
      peer: mine,
      serviceType: "Cycle-Monitor"
    )
    super.init()
    browser.delegate = self
    browser.startBrowsingForPeers()
  }
  
  public func rendered(
    _ input: Observable<(Model?, Model)>
  ) -> Observable<Action> {
    input
      .subscribe(onNext: render)
      .disposed(by: cleanup)
    return output
  }
  
  public func render(old: Model?, new: Model) {
    if session == nil {
      let session = MCSession(
        peer: mine,
        securityIdentity: nil,
        encryptionPreference: .required
      )
      session.delegate = self
      self.session = session
    }
    
    switch new {
    case .connecting(let peer):
      if let peer = peer.coerced() as MCPeerID?, let session = session {
        browser.invitePeer(
          peer,
          to: session,
          withContext: nil,
          timeout: 100
        )
      }
    case .sending(let data, let peer):
      if let peer = peer.coerced() as MCPeerID? {
        try? session?.send(
          JSONSerialization.data(
            withJSONObject: data,
            options: JSONSerialization.WritingOptions(rawValue: 0)
          ),
          toPeers: [peer],
          with: .reliable
        )
      }
    default:
      break
    }
    
//    let newConnections = new
//      .devices
//      .filter { new in
//        old?.devices.contains(
//          where: {
//            $0.peerID == new.peerID &&
//            new.transmissionState != .disconnected &&
//            $0.transmissionState == .disconnected
//          }
//        )
//        ?? false
//      }
//      .flatMap { $0.peerID.coerced() as MCPeerID? }
//
//    let newDevices = new
//      .devices
//      .filter { old?.devices.map { $0.peerID }.contains($0.peerID) == false }
//      .filter { $0.transmissionState != .disconnected }
//      .flatMap { $0.peerID.coerced() as MCPeerID? }
//
//    // Need to equality check
//    if let session = session {
//      (newConnections + newDevices).forEach { peer in
//        browser.invitePeer(
//          peer,
//          to: session,
//          withContext: nil,
//          timeout: 100
//        )
//      }
//    }
//
////    let x = ["action": "disconnect"]
////    let y = try? JSONSerialization.data(
////      withJSONObject: x,
////      options: JSONSerialization.WritingOptions(rawValue: 0)
////    )
////
////    if peerIsNew == true, let data = y, let old = old?.connectedTo?.coerced() as MCPeerID? {
////      try? session?.send(
////        data,
////        toPeers: [old],
////        with: .reliable
////      )
////    }
//
//    let newSending = new
//      .devices
//      .filter { new in
//        old?.devices.contains(
//          where: {
//            if case .sending = new.transmissionState { return
//              $0.peerID == new.peerID &&
//              new.transmissionState != $0.transmissionState
//            } else { return
//              false
//            }
//          }
//        )
//        ?? false
//      }
//      .flatMap { x -> ([AnyHashable: Any], MCPeerID)? in
//        if case .sending(let data) = x.transmissionState, let peer = x.peerID.coerced() as MCPeerID? {
//          return (data, peer)
//        } else {
//          return nil
//        }
//      }
//
//    newSending.forEach { data, peer in
//      try? session?.send(
//        JSONSerialization.data(
//          withJSONObject: data,
//          options: JSONSerialization.WritingOptions(rawValue: 0)
//        ),
//        toPeers: [peer],
//        with: .reliable
//      )
//    }
    
  }
  
  public func browser(
    _ browser: MCNearbyServiceBrowser,
    foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String: String]?
  ) {
    output.on(
      .next(
        .didFind(
          name: peerID.displayName,
          peer: peerID.coerced() as Data
        )
      )
    )
  }
  
  public func browser(
    _ browser: MCNearbyServiceBrowser,
    lostPeer peerID: MCPeerID
  ) {
    
  }
  
  func session(
    _ session: MCSession,
    peer peerID: MCPeerID,
    didChange state: MCSessionState
  ) {
    switch state {
    case .connected:
      output.on(
        .next(
          .connected(
            peerID.coerced() as Data
          )
        )
      )
    case .connecting:
      output.on(
        .next(
          .connecting(
            peerID.coerced() as Data
          )
        )
      )
    case .notConnected:
      output.on(
        .next(
          .disconnected(
            peerID.coerced() as Data
          )
        )
      )
      self.session = nil
      browser.startBrowsingForPeers()
    }
  }
  
  public func session(
    _ session: MCSession,
    didReceive data: Data,
    fromPeer peerID: MCPeerID
  ) {
    output.on(
      .next(
        .received(
          data: data,
          peer: peerID.coerced() as Data
        )
      )
    )
  }
  
  public func session(
    _ session: MCSession,
    didReceive stream: InputStream,
    withName streamName: String,
    fromPeer peerID: MCPeerID
  ) {
    
  }
  
  public func session(
    _ session: MCSession,
    didStartReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    with progress: Progress
  ) {
    
  }
  
  func session(
    _ session: MCSession,
    didFinishReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    at localURL: URL?,
    withError error: Error?
  ) {
    
  }
  
}

extension MCPeerID {
  func coerced() -> Data { return
    NSKeyedArchiver.archivedData(
      withRootObject: self
    )
  }
}

extension Data {
  func coerced() -> MCPeerID? { return
    NSKeyedUnarchiver.unarchiveObject(with: self) as? MCPeerID
  }
}

