import Foundation

private let sgAllowedUnwrappedHosts: Set<String> = ["t.me", "telegram.me", "telegram.dog"]

public func sgActionRequestHandlerSanitizer(_ url: URL) -> URL {
    var url = url
    if let scheme = url.scheme {
        let openInPrefix = "\(scheme)://parseurl?url="
        let urlString = url.absoluteString
        if urlString.hasPrefix(openInPrefix) {
            if let unwrappedUrlString = String(urlString.dropFirst(openInPrefix.count)).removingPercentEncoding, let newUrl = URL(string: unwrappedUrlString), sgIsAllowedUnwrappedUrl(newUrl, appScheme: scheme) {
                url = newUrl
            }
        }
    }
    return url
}

// Only Telegram links may be unwrapped, otherwise `parseurl` works as an open redirect to arbitrary URLs.
private func sgIsAllowedUnwrappedUrl(_ url: URL, appScheme: String) -> Bool {
    guard let scheme = url.scheme?.lowercased() else {
        return false
    }
    if scheme == "tg" || scheme == appScheme.lowercased() {
        return url.host?.lowercased() != "parseurl"
    }
    if scheme == "https" || scheme == "http", let host = url.host?.lowercased() {
        return sgAllowedUnwrappedHosts.contains(host)
    }
    return false
}
