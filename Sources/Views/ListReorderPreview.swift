import SwiftUI

struct ListReorderPreview: View {
    @State private var items = ["A", "B", "C", "D", "E"].enumerated().map { ListItem(id: $0.offset, name: $0.element) }
    @State private var selectedId: Int?

    var body: some View {
        VStack(spacing: 20) {
            Text("List(selection:), NO .onTapGesture")
                .font(.caption)

            // VERSION 1: List(selection) + onMove only
            List(selection: $selectedId) {
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        if selectedId == item.id {
                            Text("SEL")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(selectedId == item.id ? Color.green.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .tag(item.id)
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .frame(height: 200)
            .scrollContentBackground(.hidden)

            Divider()

            Text("List(selection:) + onTapGesture")
                .font(.caption)

            // VERSION 2: List(selection) + onMove + onTapGestur®e
            List(selection: $selectedId) {
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        if selectedId == item.id {
                            Text("SEL")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(selectedId == item.id ? Color.green.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .tag(item.id)
                    .onTapGesture {
                        selectedId = item.id
                    }
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.plain)
            .frame(height: 200)
            .scrollContentBackground(.hidden)
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct ListItem: Identifiable, Hashable {
    let id: Int
    let name: String
}

#Preview {
    ListReorderPreview()
}
