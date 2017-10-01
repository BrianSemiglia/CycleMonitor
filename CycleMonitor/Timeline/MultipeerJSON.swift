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
      MCNearbyServiceBrowserDelegate,
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
  
  public func browser(
    _ browser: MCNearbyServiceBrowser,
    foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String : String]?
  ) {
    if session == nil {
      browser.stopBrowsingForPeers()
      let session = MCSession(
        peer: mine,
        securityIdentity: nil,
        encryptionPreference: .required
      )
      session.delegate = self
      browser.invitePeer(
        peerID,
        to: session,
        withContext: nil,
        timeout: 100.0
      )
      self.session = session
    }
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
      output.on(.next(.connected))
    case .connecting:
      output.on(.next(.connecting))
    case .notConnected:
      output.on(.next(.disconnected))
      self.session = nil
      browser.startBrowsingForPeers()
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
