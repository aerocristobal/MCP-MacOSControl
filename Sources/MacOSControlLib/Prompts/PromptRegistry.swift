import Foundation
import MCP

public final class PromptRegistry {

    public struct Entry {
        public let definition: PromptDefinition
        public let template: PromptTemplate
    }

    private let entries: [String: Entry]
    private let orderedNames: [String]

    public init(definitions: [PromptDefinition]) {
        var byName: [String: Entry] = [:]
        var order: [String] = []
        for def in definitions {
            let template = PromptTemplate(content: def.body, arguments: def.arguments)
            byName[def.name] = Entry(definition: def, template: template)
            order.append(def.name)
        }
        self.entries = byName
        self.orderedNames = order
    }

    public static func standardRegistry() throws -> PromptRegistry {
        let definitions = try loadBundledDefinitions()
        return PromptRegistry(definitions: definitions)
    }

    public func list() -> [Prompt] {
        orderedNames.compactMap { name in
            guard let entry = entries[name] else { return nil }
            return Prompt(
                name: entry.definition.name,
                description: entry.definition.description,
                arguments: entry.definition.arguments.map {
                    Prompt.Argument(name: $0.name, description: $0.description, required: $0.required)
                },
                meta: Metadata(additionalFields: [
                    "prompt_version": .int(entry.definition.promptVersion)
                ])
            )
        }
    }

    public func get(name: String, arguments: [String: String]) throws -> GetPrompt.Result {
        guard let entry = entries[name] else {
            throw PromptError.promptNotFound(name: name, availableNames: orderedNames)
        }
        let resolved = try entry.template.resolve(arguments: arguments)
        return GetPrompt.Result(
            description: entry.definition.description,
            messages: [.user(.text(text: resolved))],
            _meta: Metadata(additionalFields: [
                "prompt_version": .int(entry.definition.promptVersion)
            ])
        )
    }

    // MARK: - Bundled definitions

    private static let bundledNames: [String] = [
        "interaction_hierarchy",
        "macos_permissions_checklist",
        "click_and_verify",
        "ax_observer_notifications"
    ]

    private static func loadBundledDefinitions() throws -> [PromptDefinition] {
        try bundledNames.map { name in
            guard let url = Bundle.module.url(
                forResource: name,
                withExtension: "md",
                subdirectory: "Definitions"
            ) else {
                throw BundleLoadError.missingResource(name)
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            return try PromptDefinition.parse(source)
        }
    }

    public enum BundleLoadError: Error, Equatable {
        case missingResource(String)
    }
}
