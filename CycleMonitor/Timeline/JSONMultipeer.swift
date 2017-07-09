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

class MultipeerJSON:
      NSObject,
      MCNearbyServiceAdvertiserDelegate,
      MCSessionDelegate {

  private let cleanup = DisposeBag()
  public let output: BehaviorSubject<[AnyHashable: Any]>
  
  var session: MCSession?
  let mine: MCPeerID
  let advertiser: MCNearbyServiceAdvertiser
  
  override init() {
    output = BehaviorSubject<[AnyHashable: Any]>(value: [:])
    mine = MCPeerID(
      displayName: Host.current().localizedName ?? "Unknown"
    )
    advertiser = MCNearbyServiceAdvertiser(
      peer: mine,
      discoveryInfo: nil,
      serviceType: "Cycle-Monitor"
    )
    super.init()
    advertiser.delegate = self
    advertiser.startAdvertisingPeer()
  }
  
  public func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didReceiveInvitationFromPeer peerID: MCPeerID,
    withContext context: Data?,
    invitationHandler: @escaping (Bool, MCSession?) -> Swift.Void
  ) {
    if session == nil {
      advertiser.stopAdvertisingPeer()
      let session = MCSession(
        peer: mine,
        securityIdentity: nil,
        encryptionPreference: .required
      )
      session.delegate = self
      invitationHandler(
        true,
        session
      )
      self.session = session
    }
  }
  
  public func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didNotStartAdvertisingPeer error: Error
  ) {
    
  }
  
  func session(
    _ session: MCSession,
    peer peerID: MCPeerID,
    didChange state: MCSessionState
  ) {
    switch state {
    case .connected:
      print("--- connected")
    case .connecting:
      print("--- connecting")
    case .notConnected:
      print("--- not connected")
    }
  }
  
  public func session(
    _ session: MCSession,
    didReceive data: Data,
    fromPeer peerID: MCPeerID
  ) {
    let info = (
        try? JSONSerialization.jsonObject(
          with: data,
          options: .allowFragments
        )
      )
      .flatMap {
        $0 as? [AnyHashable: Any]
      }
    
    if let info = info {
      output.on(.next(info))
    }
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
  
  public func session(
    _ session: MCSession,
    didFinishReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    at localURL: URL,
    withError error: Error?
  ) {
    
  }
  
  deinit {
    print("bye!")
  }

}
