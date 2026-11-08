import Foundation

enum AppConfig {
    /// Replace the owner once the GitHub repository is created. GitHub Pages
    /// serves the marketing site at the root and Docusaurus under `/docs/`.
    static let githubOwner = "YOUR_GITHUB_USERNAME"
    static let repositoryName = "fitr"
    static let repositoryURL = URL(string: "https://github.com/\(githubOwner)/\(repositoryName)")!
    static let websiteURL = URL(string: "https://\(githubOwner).github.io/\(repositoryName)/")!
    static let docsURL = URL(string: "https://\(githubOwner).github.io/\(repositoryName)/docs/")!
}
