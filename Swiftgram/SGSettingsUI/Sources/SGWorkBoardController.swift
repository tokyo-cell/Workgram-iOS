import Foundation
import SGItemListUI
import SGSimpleSettings
import AccountContext
import Display
import TelegramCore
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils

// MARK: Workgram work board — chats grouped by work tag, with private notes and a "waiting" timer.

private enum SGWorkBoardSection: Int32, SGItemListSection {
    case s0
    case s1
    case s2
    case s3
    case empty
}

private typealias SGWorkBoardEntry = SGItemListUIEntry<SGWorkBoardSection, AnyHashable, AnyHashable, AnyHashable, Int64, AnyHashable>

private func sgWorkBoardSection(for index: Int) -> SGWorkBoardSection {
    switch index {
    case 0: return .s0
    case 1: return .s1
    case 2: return .s2
    default: return .s3
    }
}

private func sgWorkElapsed(_ since: Double) -> String {
    let seconds = max(0, Date().timeIntervalSince1970 - since)
    let hours = Int(seconds / 3600.0)
    if hours < 1 {
        let minutes = Int(seconds / 60.0)
        return "\(max(1, minutes))m"
    } else if hours < 24 {
        return "\(hours)h"
    } else {
        return "\(hours / 24)d"
    }
}

private func SGWorkBoardEntries(presentationData: PresentationData, peers: [EnginePeer.Id: EnginePeer?]) -> [SGWorkBoardEntry] {
    var entries: [SGWorkBoardEntry] = []
    let id = SGItemListCounter()
    let settings = SGSimpleSettings.shared

    var hasAny = false
    for (tagIndex, tag) in workgramTags.enumerated() {
        let section = sgWorkBoardSection(for: tagIndex)
        // Collect peers with this tag.
        var rows: [(peerId: Int64, name: String, note: String?, elapsed: String?)] = []
        for key in settings.workgramChatTags.keys {
            guard settings.workgramChatTags[key] == tag.id, let raw = Int64(key) else { continue }
            let enginePeerId = EnginePeer.Id(raw)
            let name = (peers[enginePeerId] ?? nil)?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "Chat \(raw)"
            let note = settings.workgramNote(peerId: raw)
            var elapsed: String?
            if tag.id == "waiting", let date = settings.workgramTagDate(peerId: raw) {
                elapsed = sgWorkElapsed(date)
            }
            rows.append((raw, name, note, elapsed))
        }
        if rows.isEmpty { continue }
        hasAny = true
        rows.sort { $0.name.lowercased() < $1.name.lowercased() }
        entries.append(.header(id: id.count, section: section, text: "\(workgramTagTitleLocal(tag).uppercased()) (\(rows.count))", badge: nil))
        for row in rows {
            let title: String
            if let elapsed = row.elapsed {
                title = "\(row.name)  ·  waiting \(elapsed)"
            } else {
                title = row.name
            }
            entries.append(.disclosure(id: id.count, section: section, link: row.peerId, text: title))
            if let note = row.note {
                entries.append(.notice(id: id.count, section: section, text: "📝 \(note)"))
            }
        }
    }

    if !hasAny {
        entries.append(.notice(id: id.count, section: .empty, text: "No tagged chats yet. Long-press a chat in the list and open the Workgram menu to set a tag or add a note."))
    }

    return entries
}

private func workgramTagTitleLocal(_ tag: WorkgramTag) -> String {
    switch tag.id {
    case "lead": return "Lead"
    case "client": return "Client"
    case "waiting": return "Waiting"
    case "done": return "Done"
    default: return tag.id.capitalized
    }
}

public func sgWorkBoardController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<AnyHashable, AnyHashable, AnyHashable, Int64, AnyHashable>(context: context, openDisclosureLink: { peerId in
        let enginePeerId = EnginePeer.Id(peerId)
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: enginePeerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer = peer, let navigationController = getNavigationControllerImpl?() else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always, purposefulAction: {}, peekData: nil))
        })
    })

    let signal = combineLatest(context.sharedContext.presentationData, simplePromise.get())
    |> mapToSignal { presentationData, _ -> Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError> in
        var ids: [EnginePeer.Id] = []
        for key in SGSimpleSettings.shared.workgramChatTags.keys {
            if let raw = Int64(key) {
                ids.append(EnginePeer.Id(raw))
            }
        }
        return context.engine.data.get(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
        |> map { peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let entries = SGWorkBoardEntries(presentationData: presentationData, peers: peers)
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Work Board"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
            return (controllerState, (listState, arguments))
        }
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    let _ = pushControllerImpl
    let _ = workgramTagTitleLocal
    return controller
}
