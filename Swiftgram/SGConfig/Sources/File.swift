import Foundation
import BuildConfig

// Swiftgram backend (API server, settings webapp, bot) is opt-in: it is only
// contacted when the build's `sg_config` explicitly provides `api_url`,
// `webapp_url` and `bot_username`. Without them no user data leaves the device.
public struct SGConfig: Codable {
    public var apiUrl: String = ""
    public var webappUrl: String = ""
    public var botUsername: String = ""
    public var publicKey: String?
    public var iaps: [String] = []

    public var isBackendEnabled: Bool {
        return self.apiUrl.hasPrefix("https://") && self.webappUrl.hasPrefix("https://") && !self.botUsername.isEmpty
    }
}

private func parseSGConfig(_ jsonString: String) -> SGConfig {
    let jsonData = Data(jsonString.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return (try? decoder.decode(SGConfig.self, from: jsonData)) ?? SGConfig()
}

private let baseAppBundleId = Bundle.main.bundleIdentifier!
private let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
public let SG_CONFIG: SGConfig = parseSGConfig(buildConfig.sgConfig)
public let SG_API_WEBAPP_URL_PARSED: URL? = SG_CONFIG.isBackendEnabled ? URL(string: SG_CONFIG.webappUrl) : nil
