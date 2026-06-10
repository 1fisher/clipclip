import Foundation
import SwiftData
import SwiftUI

/// Manages the project list screen state.
@Observable
final class ProjectListViewModel {
    var searchText = ""
    var isShowingNewProjectAlert = false
    var newProjectTitle = ""

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createProject(title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let project = Project(title: title)
        modelContext.insert(project)
        try? modelContext.save()
        newProjectTitle = ""
    }

    func deleteProject(_ project: Project) {
        modelContext.delete(project)
        try? modelContext.save()
    }

    func filteredProjects(_ projects: [Project]) -> [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}
