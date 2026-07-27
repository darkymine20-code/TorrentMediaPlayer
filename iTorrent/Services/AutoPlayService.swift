//
//  AutoPlayService.swift
//  TorrentMediaPlayer
//
//  Created for Torrent Media Player
//

import Foundation
import UIKit
import MvvmFoundation
import LibTorrent

/// Service responsible for automatically selecting sequential download mode,
/// detecting primary video files in torrents, and auto-playing the video as soon as downloading starts.
public class AutoPlayService: @unchecked Sendable {
    public static let shared = AutoPlayService()

    private let disposeBag = DisposeBag()
    private var playedTorrents: Set<TorrentHashes> = []
    private let supportedVideoExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "m4v", "webm", "flv", "wmv", "ts", "m2ts"
    ]

    @Injected private var torrentService: TorrentService

    public init() {
        bindUpdates()
    }

    private func bindUpdates() {
        disposeBag.bind {
            torrentService.updateNotifier.sink { [weak self] model in
                self?.handleTorrentUpdate(model: model)
            }
        }
    }

    /// Automatically configure sequential mode and monitor video playback startup
    public func configureAutoSequential(for torrent: TorrentHandle) {
        torrent.setSequentialDownload(true)
        torrent.setFirstLastPiecePriority(true)
    }

    private func handleTorrentUpdate(model: TorrentService.TorrentUpdateModel) {
        guard let handle = model.handle else { return }
        let snapshot = handle.snapshot

        // Ensure sequential download is always enabled
        if !snapshot.isSequential {
            handle.setSequentialDownload(true)
            handle.setFirstLastPiecePriority(true)
        }

        let hash = snapshot.infoHashes
        guard !playedTorrents.contains(hash) else { return }

        // Find primary video file
        guard let (fileIndex, videoFile) = findPrimaryVideoFile(in: snapshot.files) else { return }

        // Trigger playback when initial bytes/downloading starts
        let isDownloadingOrReady = snapshot.state == .downloading || snapshot.state == .finished || snapshot.state == .seeding
        let hasInitialData = videoFile.downloadedBytes > 0 || videoFile.progress > 0.001 || snapshot.downloadRate > 0

        if isDownloadingOrReady && hasInitialData {
            playedTorrents.insert(hash)
            DispatchQueue.main.async { [weak self] in
                self?.launchVideoPlayer(for: handle, fileIndex: fileIndex, file: videoFile)
            }
        }
    }

    private func findPrimaryVideoFile(in files: [TorrentHandle.File]) -> (Int, TorrentHandle.File)? {
        var videoFiles: [(Int, TorrentHandle.File)] = []

        for (index, file) in files.enumerated() {
            let ext = (file.name as NSString).pathExtension.lowercased()
            if supportedVideoExtensions.contains(ext) {
                videoFiles.append((index, file))
            }
        }

        // Return largest video file by size
        return videoFiles.max(by: { $0.1.size < $1.1.size })
    }

    private func launchVideoPlayer(for handle: TorrentHandle, fileIndex: Int, file: TorrentHandle.File) {
        guard let topVC = UIApplication.shared.topMostViewController() else { return }

        let fileURL = handle.snapshot.downloadPath.appendingPathComponent(file.name)
        #if DEBUG
        print("[AutoPlayService] Auto-launching VLC Player for video: \(file.name) at URL: \(fileURL)")
        #endif

        let config = VLCPlayerViewModel.Config(url: fileURL, torrentPair: (handle, fileIndex))
        let playerVM = VLCPlayerViewModel()
        playerVM.prepare(with: config)

        let playerVC = VLCPlayerViewController(viewModel: playerVM)
        let nav = UINavigationController(rootViewController: playerVC)
        nav.modalPresentationStyle = .fullScreen

        topVC.present(nav, animated: true)
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topMostViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}
