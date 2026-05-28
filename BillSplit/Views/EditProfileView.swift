import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var displayName: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var avatarUrl: String?
    @State private var isUploading = false

    init(displayName: String, avatarUrl: String?) {
        _displayName = State(initialValue: displayName)
        _avatarUrl = State(initialValue: avatarUrl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            AvatarView(
                                avatarUrl: avatarUrl,
                                displayName: displayName,
                                size: 100
                            )
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("选择照片", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        loadImage(from: newItem)
                    }
                }

                Section("名字") {
                    TextField("显示名称", text: $displayName)
                }

                Section {
                    Button("保存") {
                        save()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { self.selectedImage = image }
            }
        }
    }

    private func save() {
        guard let userId = authVM.currentUserId else { return }
        isUploading = true

        Task {
            _ = try? await supabase.from("users")
                .update(["display_name": displayName])
                .eq("id", value: userId)
                .execute()

            if let image = selectedImage,
               let url = try? await StorageService.shared.uploadAvatar(userId: userId, image: image) {
                _ = try? await supabase.from("users")
                    .update(["avatar_url": url])
                    .eq("id", value: userId)
                    .execute()
            }

            await MainActor.run {
                isUploading = false
                dismiss()
            }
        }
    }
}
