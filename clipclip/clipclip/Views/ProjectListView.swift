import SwiftUI
import SwiftData

struct ProjectListView: View {
    let projects: [Project]
    @Binding var navigationPath: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @State private var isShowingNewProject = false
    @State private var newProjectTitle = ""

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "video.slash",
                    description: Text("Create a project to start editing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            ProjectRow(project: project)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(projects[index])
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle("ClipClip")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingNewProject = true }) {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
        .alert("New Project", isPresented: $isShowingNewProject) {
            TextField("Project Name", text: $newProjectTitle)
            Button("Cancel", role: .cancel) {
                newProjectTitle = ""
            }
            Button("Create") {
                guard !newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let project = Project(title: newProjectTitle)
                modelContext.insert(project)
                try? modelContext.save()
                newProjectTitle = ""
            }
        } message: {
            Text("Enter a name for your video project.")
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)

                if project.tracks.flatMap({ $0.clips }).isEmpty {
                    Image(systemName: "video")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label("\(project.tracks.flatMap({ $0.clips }).count) clips", systemImage: "film")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(project.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProjectListView(
            projects: [],
            navigationPath: .constant(NavigationPath())
        )
        .modelContainer(for: Project.self, inMemory: true)
    }
}
