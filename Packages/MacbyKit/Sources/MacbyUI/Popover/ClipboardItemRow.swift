import SwiftUI
import MacbyCore

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if let sourceAppName = item.sourceAppName {
                    Text(sourceAppName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var title: String {
        switch item.contentType {
        case .text, .rtf, .url:
            return item.textPreview ?? ""
        case .image:
            return "Image"
        case .fileList:
            let names = (item.fileURLs ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }
            return names.joined(separator: ", ")
        }
    }

    private var icon: Image {
        switch item.contentType {
        case .text, .rtf, .url: Image(systemName: "doc.text")
        case .image: Image(systemName: "photo")
        case .fileList: Image(systemName: "doc")
        }
    }
}
