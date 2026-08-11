//
//  ReceiptSection.swift
//  I Got Gas
//
//  Receipt photos on an expense.
//
//  Thumbnails are stored on the model and sync inline, so this grid draws
//  without touching the network. Tapping fetches the full image.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptSection: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncManager.self) private var syncManager

    /// Nil while the expense hasn't been saved yet — a photo needs something
    /// to hang off, so capture is offered only after the first save.
    let service: SDService?

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var viewing: SDAttachment?
    @State private var importing = false

    private var attachments: [SDAttachment] {
        guard let service else { return [] }
        return (service.attachments ?? [])
            .filter { !$0.deleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Section {
            if service == nil {
                Text("Save this expense to add a receipt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if !attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(attachments) { attachment in
                                ReceiptThumbnail(attachment: attachment)
                                    .onTapGesture { viewing = attachment }
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            delete(attachment)
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label("Add Photo", systemImage: "photo.on.rectangle")
                }

                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                if importing {
                    HStack {
                        ProgressView()
                        Text("Processing…").foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Receipts")
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPicked(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await add(image: image) }
            }
        }
        .sheet(item: $viewing) { attachment in
            ReceiptViewer(attachment: attachment)
        }
    }

    // MARK: - Import

    private func importPicked(_ items: [PhotosPickerItem]) async {
        importing = true
        defer {
            importing = false
            pickerItems = []
        }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            await add(data: data)
        }
    }

    private func add(image: UIImage) async {
        guard let prepared = AttachmentStore.prepare(image) else { return }
        store(prepared)
    }

    private func add(data: Data) async {
        guard let prepared = AttachmentStore.prepare(data: data) else { return }
        store(prepared)
    }

    private func store(_ prepared: AttachmentStore.Prepared) {
        guard let service else { return }

        // The same photo added twice is almost always a mistake.
        if attachments.contains(where: { $0.sha256 == prepared.sha256 }) { return }

        let attachment = SDAttachment()
        attachment.service = service
        attachment.filename = "receipt-\(attachment.id).jpg"
        attachment.mimeType = "image/jpeg"
        attachment.byteSize = prepared.data.count
        attachment.sha256 = prepared.sha256
        attachment.width = prepared.width
        attachment.height = prepared.height
        attachment.thumbnailData = prepared.thumbnail
        attachment.localFilename = AttachmentStore.write(prepared.data, for: attachment.id)
        attachment.uploadState = .pendingUpload

        context.insert(attachment)
        try? context.save()

        syncManager.recordAttachment(attachment)
        Task { await AttachmentTransfer.shared.uploadPending(context: context) }
    }

    private func delete(_ attachment: SDAttachment) {
        // Soft delete, like everything else — it stays restorable until the
        // retention window closes.
        attachment.deleted = true
        attachment.touch()
        try? context.save()
        syncManager.recordAttachment(attachment)
    }
}

private struct ReceiptThumbnail: View {
    let attachment: SDAttachment

    var body: some View {
        Group {
            if let data = attachment.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) {
            if attachment.uploadState == .pendingUpload {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.white, .orange)
                    .padding(3)
            } else if attachment.uploadState == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.white, .red)
                    .padding(3)
            }
        }
    }
}

/// Full-size viewer. Downloads on demand — only thumbnails are kept everywhere.
private struct ReceiptViewer: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let attachment: SDAttachment

    @State private var image: UIImage?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableImage(image: image)
                } else if loading {
                    ProgressView()
                } else {
                    ContentUnavailableView(
                        "Image Unavailable",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("This receipt could not be loaded.")
                    )
                }
            }
            .navigationTitle(attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let path = attachment.localPath, let data = try? Data(contentsOf: path) {
                    image = UIImage(data: data)
                } else {
                    let data = await AttachmentTransfer.shared.download(attachment, context: context)
                    image = data.flatMap(UIImage.init(data:))
                }
                loading = false
            }
        }
    }
}

private struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { scale = max(1, $0.magnification) }
                    .onEnded { _ in withAnimation { scale = max(1, scale) } }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2.5 }
            }
    }
}

/// Minimal camera bridge — `PhotosPicker` covers the library, but not capture.
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
