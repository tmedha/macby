import AppKit
import SwiftUI
import MacbyCore

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            leadingThumbnail
                .frame(width: 20, height: 20)

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

            if item.sensitivityKind == .otp {
                otpBadge
            }

            if item.isSensitive {
                sensitiveBadge
            }

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

    private var otpBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: item.otpCleared ? "checkmark.circle" : "key.fill")
            Text(item.otpCleared ? "Cleared" : "OTP")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(item.otpCleared ? Color.secondary : Color.orange)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule().fill((item.otpCleared ? Color.gray : Color.orange).opacity(0.15))
        )
    }

    private var sensitiveBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
            Text(item.sensitivityKind == .ssn ? "SSN" : "Card")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Color.red)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.red.opacity(0.15)))
    }

    @ViewBuilder
    private var leadingThumbnail: some View {
        if item.contentType == .image,
           let path = item.imageThumbnailPath,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            icon.foregroundStyle(.secondary)
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
