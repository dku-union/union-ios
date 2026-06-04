import SwiftUI
import PhotosUI

// MARK: - Profile Edit View

/// 프로필 수정 — 닉네임(PATCH /me) + 프로필 이미지(upload-url → GCS PUT → PATCH /me/profile-image).
/// 저장 성공 시 `onUpdated` 로 갱신된 프로필을 부모(ProfileView)에 전달한다.
struct ProfileEditView: View {
    let profile: UserProfile
    let onUpdated: (UserProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let nicknameLimit = 50

    init(profile: UserProfile, onUpdated: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onUpdated = onUpdated
        self._nickname = State(initialValue: profile.nickname)
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        pickedImage != nil || (trimmedNickname != profile.nickname && !trimmedNickname.isEmpty)
    }

    var body: some View {
        Form {
            photoSection
            nicknameSection
        }
        .navigationTitle("프로필 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("저장") { save() }
                        .disabled(!hasChanges)
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pickedImage = image
                }
            }
        }
        .alert("저장 실패", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .tint(UNColor.interactive)
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Spacer()
                    avatar
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                Text("사진 변경")
                    .font(UNFont.bodyMedium(.medium))
                    .foregroundStyle(UNColor.interactive)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
    }

    private var nicknameSection: some View {
        Section {
            TextField("닉네임", text: $nickname)
                .textInputAutocapitalization(.never)
                .onChange(of: nickname) { _, newValue in
                    if newValue.count > nicknameLimit {
                        nickname = String(newValue.prefix(nicknameLimit))
                    }
                }
        } header: {
            Text("닉네임")
        } footer: {
            Text("\(trimmedNickname.count)/\(nicknameLimit)")
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            if let pickedImage {
                Image(uiImage: pickedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let urlString = profile.profileImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        emojiAvatar
                    }
                }
            } else {
                emojiAvatar
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(7)
                .background(UNColor.interactive, in: Circle())
                .overlay(Circle().stroke(UNColor.surface, lineWidth: 2))
        }
    }

    private var emojiAvatar: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: UNColor.gradientRedAccent,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(profile.profileEmoji).font(.system(size: 40))
        }
    }

    // MARK: - Save

    private func save() {
        guard hasChanges, !isSaving else { return }
        isSaving = true
        Task {
            do {
                var latest: UserMeResponse?

                if trimmedNickname != profile.nickname && !trimmedNickname.isEmpty {
                    latest = try await UserClient.liveValue.updateNickname(trimmedNickname)
                }

                if let pickedImage, let jpeg = pickedImage.jpegData(compressionQuality: 0.8) {
                    latest = try await UserClient.liveValue.changeProfileImage(jpeg)
                }

                isSaving = false
                if let latest {
                    onUpdated(latest.toUserProfile())
                }
                dismiss()
            } catch {
                isSaving = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
