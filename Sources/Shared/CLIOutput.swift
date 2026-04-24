import Foundation

enum CLIOutputMode: Equatable {
    case text
    case json

    init(jsonFlag: Bool, stdoutIsTTY: Bool) {
        self = jsonFlag || !stdoutIsTTY ? .json : .text
    }
}

enum CLIJSONValue: Codable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }
}

struct CLIProviderSummary {
    static let defaultFields = ["id", "name", "type", "active", "model", "base_url"]

    static func makeList(
        from providers: [Provider],
        limit: Int?,
        fields: [String]?
    ) -> [[String: CLIJSONValue]] {
        let selectedFields = fields?.filter { !$0.isEmpty } ?? defaultFields
        let safeLimit = max(0, limit ?? providers.count)
        return providers.prefix(safeLimit).map { provider in
            make(provider: provider, fields: selectedFields)
        }
    }

    static func make(provider: Provider, fields: [String]? = nil) -> [String: CLIJSONValue] {
        let selectedFields = fields?.filter { !$0.isEmpty } ?? defaultFields
        let values: [String: CLIJSONValue] = [
            "id": .string(provider.id.uuidString.lowercased()),
            "name": .string(provider.name),
            "type": .string(provider.type.rawValue),
            "active": .bool(provider.isActive),
            "model": provider.model.map(CLIJSONValue.string) ?? .null,
            "base_url": .string(provider.baseUrl),
            "sort_order": .int(provider.sortOrder),
            "oauth_display_name": provider.oauthDisplayName.map(CLIJSONValue.string) ?? .null
        ]

        return Dictionary(uniqueKeysWithValues: selectedFields.compactMap { field in
            values[field].map { (field, $0) }
        })
    }
}

struct CLIErrorPayload: Codable, Equatable {
    let code: String
    let message: String
    let input: [String: String]?
    let retryable: Bool
    let suggestion: String?

    var exitCode: Int {
        retryable ? 2 : 1
    }
}

struct CLIErrorEnvelope: Codable, Equatable {
    let error: CLIErrorPayload
}
