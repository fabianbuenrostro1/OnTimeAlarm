import Foundation
import MusicKit
import SwiftUI

/// Manages Apple Music integration for prep time playback
@MainActor
final class PrepTimeMusicManager: ObservableObject {
    static let shared = PrepTimeMusicManager()

    @Published private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published private(set) var userPlaylists: [Playlist] = []
    @Published private(set) var isLoadingPlaylists: Bool = false

    private let player = ApplicationMusicPlayer.shared

    private init() {
        // Check initial authorization status
        Task {
            authorizationStatus = MusicAuthorization.currentStatus
        }
    }

    // MARK: - Authorization

    /// Request authorization to access the user's music library
    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        authorizationStatus = status

        if status == .authorized {
            // Fetch playlists after authorization
            try? await fetchPlaylists()
        }

        return status
    }

    // MARK: - Fetch Playlists

    /// Fetch the user's playlists from their library
    func fetchPlaylists() async throws {
        guard authorizationStatus == .authorized else {
            print("PrepTimeMusicManager: Not authorized to access music library")
            return
        }

        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }

        var request = MusicLibraryRequest<Playlist>()
        request.sort(by: \.lastPlayedDate, ascending: false)

        let response = try await request.response()
        userPlaylists = Array(response.items)

        print("PrepTimeMusicManager: Fetched \(userPlaylists.count) playlists")
    }

    // MARK: - Playback

    /// Play a playlist or album by its MusicKit ID
    func play(mediaId: String) async throws {
        guard authorizationStatus == .authorized else {
            print("PrepTimeMusicManager: Not authorized to play music")
            return
        }

        // Try to find the playlist by ID
        if let playlist = userPlaylists.first(where: { $0.id.rawValue == mediaId }) {
            try await playPlaylist(playlist)
            return
        }

        // If not in cache, fetch it directly
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(mediaId))
        let response = try await request.response()

        if let playlist = response.items.first {
            try await playPlaylist(playlist)
        } else {
            print("PrepTimeMusicManager: Could not find playlist with ID \(mediaId)")
        }
    }

    private func playPlaylist(_ playlist: Playlist) async throws {
        // Get the playlist with tracks
        let detailedPlaylist = try await playlist.with([.tracks])

        guard let tracks = detailedPlaylist.tracks, !tracks.isEmpty else {
            print("PrepTimeMusicManager: Playlist has no tracks")
            return
        }

        // Set the queue and play
        player.queue = ApplicationMusicPlayer.Queue(for: tracks)
        try await player.play()

        print("PrepTimeMusicManager: Started playing '\(playlist.name)'")
    }

    /// Stop playback
    func stop() {
        player.stop()
        print("PrepTimeMusicManager: Stopped playback")
    }

    /// Pause playback
    func pause() {
        player.pause()
    }

    /// Preview a playlist (play briefly for selection UI)
    func preview(mediaId: String) async throws {
        // For preview, just start playing - user can stop by selecting
        try await play(mediaId: mediaId)
    }

    // MARK: - Display Helpers

    /// Get the display name for the current media selection
    func displayName(for mediaName: String?) -> String {
        mediaName ?? "Silence"
    }

    /// Get artwork URL for a playlist
    func artworkURL(for playlist: Playlist, width: Int = 100, height: Int = 100) -> URL? {
        playlist.artwork?.url(width: width, height: height)
    }
}

// MARK: - PrepTimeMediaType Enum

enum PrepTimeMediaType: String, CaseIterable {
    case silence = "silence"
    case appleMusic = "appleMusic"

    var displayName: String {
        switch self {
        case .silence: return "Silence"
        case .appleMusic: return "Apple Music"
        }
    }

    var icon: String {
        switch self {
        case .silence: return "speaker.slash"
        case .appleMusic: return "music.note"
        }
    }
}
