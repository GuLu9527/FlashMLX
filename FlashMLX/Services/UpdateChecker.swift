import Foundation
import AppKit

class UpdateChecker: ObservableObject {
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var isChecking = false
    @Published var hasUpdate = false

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let repoOwner = "GuLu9527"
    private let repoName = "FlashMLX"

    var currentVersionDisplay: String { currentVersion }

    func check() {
        guard !isChecking else { return }
        isChecking = true

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else { return }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self?.latestVersion = remote

                if let assets = json["assets"] as? [[String: Any]],
                   let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                   let url = dmg["browser_download_url"] as? String {
                    self?.downloadURL = url
                }

                self?.hasUpdate = self?.isNewer(remote: remote, current: self?.currentVersion ?? "0") ?? false
            }
        }.resume()
    }

    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }

    func openDownloadPage() {
        if let url = downloadURL, let nsURL = URL(string: url) {
            NSWorkspace.shared.open(nsURL)
        } else {
            let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
            NSWorkspace.shared.open(url)
        }
    }
}
