import Foundation

enum CatalogStore {
    static func load() -> CatalogResource? {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CatalogResource.self, from: data)
    }
}

enum BootstrapCache {
    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = base.appendingPathComponent("Fitr", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("bootstrap.json")
    }

    static func save(_ bootstrap: Bootstrap) {
        guard let fileURL, let data = try? JSONEncoder().encode(bootstrap) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> Bootstrap? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Bootstrap.self, from: data)
    }

    static func clear() {
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }
}

extension Facets {
    static let empty = Facets(topics: [], types: [], regions: [], muscles: [], timeRegions: [])
}
