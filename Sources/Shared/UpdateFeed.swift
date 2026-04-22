import Foundation

struct UpdateFeedItem: Equatable {
    let version: String
    let shortVersion: String
    let downloadURL: URL
    let sha256: String?
    let length: Int64?
    let minimumSystemVersion: String?
    let releaseNotes: String?
}

enum UpdateFeedParser {
    enum ParseError: LocalizedError {
        case missingItem
        case missingDownloadURL
        case invalidDownloadURL(String)

        var errorDescription: String? {
            switch self {
            case .missingItem:
                return "更新源中没有找到版本信息。"
            case .missingDownloadURL:
                return "更新源中没有找到下载地址。"
            case .invalidDownloadURL(let value):
                return "更新源下载地址无效：\(value)"
            }
        }
    }

    static func parse(_ xml: String) throws -> UpdateFeedItem {
        let delegate = FeedXMLDelegate()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate

        guard parser.parse(), let item = delegate.item else {
            throw parser.parserError ?? ParseError.missingItem
        }

        guard let urlString = item.enclosureAttributes["url"], !urlString.isEmpty else {
            throw ParseError.missingDownloadURL
        }

        guard let downloadURL = URL(string: urlString) else {
            throw ParseError.invalidDownloadURL(urlString)
        }

        let version = item.enclosureAttributes["sparkle:version"] ?? item.version ?? item.shortVersion ?? ""
        let shortVersion = item.enclosureAttributes["sparkle:shortVersionString"] ?? item.shortVersion ?? version
        let length = item.enclosureAttributes["length"].flatMap(Int64.init)

        return UpdateFeedItem(
            version: version,
            shortVersion: shortVersion,
            downloadURL: downloadURL,
            sha256: item.enclosureAttributes["sparkle:sha256"],
            length: length,
            minimumSystemVersion: item.minimumSystemVersion,
            releaseNotes: cleanReleaseNotes(item.description)
        )
    }

    static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }

    private static func cleanReleaseNotes(_ rawValue: String?) -> String? {
        guard var text = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        text = text.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        let replacements = [
            "<h1>": "# ", "</h1>": "\n\n",
            "<h2>": "## ", "</h2>": "\n\n",
            "<h3>": "### ", "</h3>": "\n\n",
            "<p>": "", "</p>": "\n\n",
            "<ul>": "\n", "</ul>": "\n",
            "<ol>": "\n", "</ol>": "\n",
            "<li>": "- ", "</li>": "\n",
            "<strong>": "**", "</strong>": "**",
            "<b>": "**", "</b>": "**",
            "<em>": "*", "</em>": "*",
            "<i>": "*", "</i>": "*",
            "<code>": "`", "</code>": "`",
            "<br>": "\n", "<br/>": "\n", "<br />": "\n"
        ]

        for (target, replacement) in replacements {
            text = text.replacingOccurrences(of: target, with: replacement)
                .replacingOccurrences(of: target.uppercased(), with: replacement)
        }

        text = stripRemainingHTMLTags(from: text)

        let cleaned = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return cleaned.isEmpty ? nil : cleaned
    }

    private static func stripRemainingHTMLTags(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}

private final class FeedXMLDelegate: NSObject, XMLParserDelegate {
    struct Item {
        var enclosureAttributes: [String: String] = [:]
        var description: String?
        var version: String?
        var shortVersion: String?
        var minimumSystemVersion: String?
    }

    private(set) var item: Item?
    private var currentItem: Item?
    private var currentElement = ""
    private var currentText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = qName ?? elementName
        currentElement = name
        currentText = ""

        if name == "item" {
            currentItem = Item()
        } else if name == "enclosure", currentItem != nil {
            currentItem?.enclosureAttributes = attributeDict
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "item":
            if item == nil {
                item = currentItem
            }
            currentItem = nil
        case "description":
            currentItem?.description = text
        case "sparkle:version":
            currentItem?.version = text
        case "sparkle:shortVersionString":
            currentItem?.shortVersion = text
        case "sparkle:minimumSystemVersion":
            currentItem?.minimumSystemVersion = text
        default:
            break
        }

        currentElement = ""
        currentText = ""
    }
}
