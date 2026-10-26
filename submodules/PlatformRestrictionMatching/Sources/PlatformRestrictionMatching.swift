import Foundation
import Postbox
import TelegramCore

public extension EngineRawMessage {
    func isRestricted(platform: String, contentSettings: ContentSettings) -> Bool {
        return self.restrictionReason(platform: platform, contentSettings: contentSettings) != nil
    }

    func restrictionReason(platform: String, contentSettings: ContentSettings) -> String? {
        if let attribute = self.restrictedContentAttribute {
            if let value = attribute.platformText(platform: platform, contentSettings: contentSettings) {
                return value
            }
        }
        return nil
    }
}

public extension RestrictedContentMessageAttribute {
    func platformText(platform: String, contentSettings: ContentSettings, chatId: Int64? = nil) -> String? {
        for rule in self.rules {
            if rule.reason == "sensitive" {
                continue
            }
            if rule.platform == "all" || rule.platform == "ios" || contentSettings.addContentRestrictionReasons.contains(rule.platform) {
                if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                    return rule.text + "\n" + "\(rule.reason)-\(rule.platform)"
                }
            }
        }
        return nil
    }
}

// MARK: Workgram — never reveal copy-protected content.
public extension Message {
    func canRevealContent(contentSettings: ContentSettings) -> Bool {
        return false
    }
}
