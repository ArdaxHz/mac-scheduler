//
//  UpdateService.swift
//  MacScheduler
//
//  Checks for new releases on GitHub.
//

import Foundation

actor UpdateService {
    static let shared = UpdateService()

    private let repoOwner = "ArdaxHz"
    private let repoName = "mac-scheduler"

    struct Release {
        let tagName: String
        let version: String
        let htmlURL: String
        let publishedAt: Date?
        let body: String
    }

    /// Fetch the latest GitHub release and compare with the current app version.
    func checkForUpdate() async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else {
                return nil
            }

            let remoteVersion = extractVersion(from: tagName)
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            guard isNewer(remote: remoteVersion, current: currentVersion) else {
                return nil
            }

            let body = json["body"] as? String ?? ""
            var publishedAt: Date?
            if let dateStr = json["published_at"] as? String {
                let formatter = ISO8601DateFormatter()
                publishedAt = formatter.date(from: dateStr)
            }

            return Release(
                tagName: tagName,
                version: remoteVersion,
                htmlURL: htmlURL,
                publishedAt: publishedAt,
                body: body
            )
        } catch {
            return nil
        }
    }

    /// Extract semver from a GitHub release tag.
    /// CI tags follow `v{MARKETING_VERSION}-{SHORT_SHA}`, e.g.:
    ///   "v0.6.0-abc1234"       → "0.6.0"
    ///   "v0.6.0-alpha-abc1234" → "0.6.0-alpha"
    ///   "v1.0.0-beta.2-abc1234" → "1.0.0-beta.2"
    /// The trailing commit hash (7+ hex chars after the last dash) is stripped,
    /// but pre-release labels are preserved.
    private func extractVersion(from tag: String) -> String {
        var version = tag
        // Strip surrounding quotes (defense against CI quoting issues)
        version = version.replacingOccurrences(of: "\"", with: "")
        if version.hasPrefix("v") { version = String(version.dropFirst()) }
        // Strip trailing commit hash suffix: last segment after `-` that is 7+ hex chars
        if let lastDash = version.lastIndex(of: "-") {
            let suffix = String(version[version.index(after: lastDash)...])
            let isCommitHash = suffix.count >= 7 && suffix.allSatisfy { $0.isHexDigit }
            if isCommitHash {
                version = String(version[..<lastDash])
            }
        }
        return version
    }

    /// Parse a version string into numeric components, stripping any pre-release suffix.
    /// e.g. "1.3.0-alpha" → [1, 3, 0], "1.3.0" → [1, 3, 0]
    private func parseVersion(_ version: String) -> [Int] {
        // Strip quotes defensively
        var cleaned = version.replacingOccurrences(of: "\"", with: "")
        // Strip pre-release suffix (e.g. "-alpha", "-beta") before splitting
        if let dashIndex = cleaned.firstIndex(of: "-") {
            cleaned = String(cleaned[..<dashIndex])
        }
        return cleaned.split(separator: ".").compactMap { Int($0) }
    }

    /// Extract the pre-release suffix from a version string.
    /// "0.6.0-alpha" → "alpha", "1.0.0-beta.2" → "beta.2", "1.0.0" → nil
    private func preReleaseSuffix(_ version: String) -> String? {
        let cleaned = version.replacingOccurrences(of: "\"", with: "")
        guard let dashIndex = cleaned.firstIndex(of: "-") else { return nil }
        let suffix = String(cleaned[cleaned.index(after: dashIndex)...])
        return suffix.isEmpty ? nil : suffix
    }

    /// Compare semver strings. Returns true if remote is newer than current.
    /// Follows semver pre-release precedence:
    ///   0.6.0-alpha < 0.6.0-alpha.1 < 0.6.0-beta < 0.6.0-rc.1 < 0.6.0
    private func isNewer(remote: String, current: String) -> Bool {
        let remoteParts = parseVersion(remote)
        let currentParts = parseVersion(current)

        for i in 0..<max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }

        // Numeric parts are equal — compare pre-release labels per semver
        let remotePre = preReleaseSuffix(remote)
        let currentPre = preReleaseSuffix(current)

        switch (remotePre, currentPre) {
        case (nil, nil):
            return false // Both stable, same version
        case (nil, .some):
            return true  // Remote is stable, current is pre-release → update
        case (.some, nil):
            return false // Remote is pre-release, current is stable → no update
        case let (.some(rPre), .some(cPre)):
            return comparePreRelease(rPre, isNewerThan: cPre)
        }
    }

    /// Compare pre-release identifiers per semver specification.
    /// Identifiers are dot-separated and compared left to right:
    ///   - Numeric identifiers are compared as integers
    ///   - String identifiers are compared lexically
    ///   - Numeric identifiers always have lower precedence than string identifiers
    ///   - A larger set of identifiers has higher precedence if all preceding are equal
    /// Examples: "alpha" < "alpha.1" < "beta" < "beta.2" < "beta.11" < "rc.1"
    private func comparePreRelease(_ remote: String, isNewerThan current: String) -> Bool {
        let remoteIds = remote.split(separator: ".")
        let currentIds = current.split(separator: ".")

        for i in 0..<max(remoteIds.count, currentIds.count) {
            // Fewer identifiers = lower precedence (if all preceding are equal)
            guard i < remoteIds.count else { return false }
            guard i < currentIds.count else { return true }

            let r = remoteIds[i]
            let c = currentIds[i]
            if r == c { continue }

            let rNum = Int(r)
            let cNum = Int(c)

            switch (rNum, cNum) {
            case let (.some(rn), .some(cn)):
                return rn > cn  // Both numeric: compare as integers
            case (.some, nil):
                return false    // Numeric < string per semver
            case (nil, .some):
                return true     // String > numeric per semver
            case (nil, nil):
                return r > c    // Both strings: lexicographic comparison
            }
        }
        return false // Equal
    }
}
