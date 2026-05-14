import Foundation

public enum PromptError: Error, Equatable {
    case missingRequiredArgument(name: String)
    case unknownPlaceholder(name: String)
    case promptNotFound(name: String, availableNames: [String])

    public var code: String {
        switch self {
        case .missingRequiredArgument: return "missing_required_argument"
        case .unknownPlaceholder: return "missing_required_argument"
        case .promptNotFound: return "prompt_not_found"
        }
    }

    public var message: String {
        switch self {
        case .missingRequiredArgument(let name):
            return "Required argument \"\(name)\" was not provided."
        case .unknownPlaceholder(let name):
            return "Prompt body contains placeholder \"{\(name)}\" but no argument with that name is declared."
        case .promptNotFound(let name, _):
            return "No prompt is registered with name \"\(name)\"."
        }
    }

    public var details: [String: Any]? {
        switch self {
        case .missingRequiredArgument(let name):
            return ["argument": name]
        case .unknownPlaceholder(let name):
            return ["argument": name]
        case .promptNotFound(_, let availableNames):
            return ["available": availableNames]
        }
    }
}
