//
//  PeerReconnectService.swift
//  TorrentMediaPlayer
//
//  Created for Torrent Media Player
//

import Foundation
import MvvmFoundation
import LibTorrent

/// Service responsible for automatically reconnecting to peers and re-announcing to trackers
/// until torrent downloading begins.
public class PeerReconnectService: @unchecked Sendable {
    public static let shared = PeerReconnectService()

    private let disposeBag = DisposeBag()
    private var timer: Timer?
    @Injected private var torrentService: TorrentService

    private let reannounceInterval: TimeInterval = 5.0

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: self.reannounceInterval, repeats: true) { [weak self] _ in
                self?.performPeerReconnectionCheck()
            }
        }
    }

    public func performPeerReconnectionCheck() {
        let activeTorrents = torrentService.torrents.values
        for torrent in activeTorrents {
            let snapshot = torrent.snapshot
            
            // Check if downloading metadata or downloading but zero active peers / zero rate
            let needsReconnect = (snapshot.state == .downloadingMetadata) ||
                                (snapshot.state == .downloading && (snapshot.peersConnected == 0 || snapshot.downloadRate == 0))
            
            if needsReconnect && !snapshot.isPaused {
                #if DEBUG
                print("[PeerReconnectService] Automatically forcing peer re-announce for torrent: \(snapshot.name)")
                #endif
                torrent.forceReannounce()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
