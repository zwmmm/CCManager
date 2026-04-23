import SwiftUI

struct ProviderListView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showingAddSheet: Bool

    @State private var providerToEdit: Provider?
    @State private var showingDeleteConfirmation = false
    @State private var providerToDelete: Provider?

    var body: some View {
        List(selection: Binding(
            get: { providerStore.activeProvider?.id },
            set: { newId in
                if let id = newId, let provider = providerStore.providers.first(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        providerStore.setActiveProvider(provider)
                    }
                }
            }
        )) {
            ForEach(providerStore.providers) { provider in
                ProviderRowView(provider: provider)
                    .environmentObject(themeManager)
                    .tag(provider.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            providerToDelete = provider
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            providerToEdit = provider
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
            }
            .onMove { from, to in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    providerStore.moveProvider(from: from, to: to)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Providers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingAddSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .confirmationDialog(
            "Delete Provider",
            isPresented: $showingDeleteConfirmation,
            presenting: providerToDelete
        ) { provider in
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    providerStore.deleteProvider(provider)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { provider in
            Text("Delete \"\(provider.name)\"?")
        }
        .sheet(item: $providerToEdit) { provider in
            ProviderFormView(mode: .edit(provider)) { updatedProvider in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    providerStore.updateProvider(updatedProvider)
                }
            }
        }
    }
}

struct ProviderRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let provider: Provider
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            CachedPixelAvatarView(name: provider.name, type: provider.type, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .monospaced))
                    .lineLimit(1)

                Text(provider.type.rawValue)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if provider.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.brandColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? themeManager.brandColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
