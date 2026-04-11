import Foundation

enum DevCacheRulesLoader {
    static func loadFromBundle() throws -> DevCacheRulesDocument {
        guard let url = Bundle.safeURL(forResource: "dev_cache_rules", withExtension: "json") else {
            throw RulesError.missingResource
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(DevCacheRulesDocument.self, from: data)
    }

    enum RulesError: LocalizedError {
        case missingResource

        var errorDescription: String? {
            switch self {
            case .missingResource:
                return "找不到 dev_cache_rules.json"
            }
        }
    }
}
