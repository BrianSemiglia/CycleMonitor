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

  enum Action {
    case launching
    case connecting
    case connected
    case disconnected
    case received(data: Data)
  }
  
  private let cleanup = DisposeBag()
  public let output: BehaviorSubject<Action>
  
  var session: MCSession?
  let mine: MCPeerID
  let advertiser: MCNearbyServiceAdvertiser
  
  override init() {
    output = BehaviorSubject<Action>(value: .launching)
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
  
  public func rendered(
    _ input: Observable<[AnyHashable: Any]>
  ) -> Observable<Action> {
    input
      .subscribe(onNext: render)
      .disposed(by: cleanup)
    return output
  }
  
  func render(_ input: [AnyHashable: Any]) {
    if let connected = session?.connectedPeers {
      try? session?.send(
        JSONSerialization.data(
          withJSONObject: input,
          options: JSONSerialization.WritingOptions(rawValue: 0)
        ),
        toPeers: connected,
        with: .reliable
      )
    }
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
      output.on(.next(.connected))
    case .connecting:
      output.on(.next(.connecting))
    case .notConnected:
      output.on(.next(.disconnected))
      self.session = nil
      advertiser.startAdvertisingPeer()
    }
  }
  
  public func session(
    _ session: MCSession,
    didReceive data: Data,
    fromPeer peerID: MCPeerID
  ) {
    output.on(.next(.received(data: data)))
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
