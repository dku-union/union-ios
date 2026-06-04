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
            var latest: UserMeResponse?

            // 1) 닉네임 먼저 반영. 실패하면 이미지 업로드는 시도하지 않는다.
            if trimmedNickname != profile.nickname && !trimmedNickname.isEmpty {
                do {
                    latest = try await UserClient.liveValue.updateNickname(trimmedNickname)
                } catch {
                    finishWithError(error)
                    return
                }
            }

            // 2) 이미지 업로드. 닉네임은 이미 서버에 반영됐을 수 있으므로, 이미지 실패 시에도
            //    그때까지의 성공분(닉네임)을 부모에 전파한 뒤 오류만 표시한다(부분 성공 일관성).
            if let pickedImage {
                let resized = Self.downsampled(pickedImage)
                guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
                    finishWithError(UserClientError.uploadFailed, partial: latest)
                    return
                }
                do {
                    latest = try await UserClient.liveValue.changeProfileImage(jpeg)
                } catch {
                    finishWithError(error, partial: latest)
                    return
                }
            }

            isSaving = false
            if let latest { onUpdated(latest.toUserProfile()) }
            dismiss()
        }
    }

    /// 실패 처리. `partial` 이 있으면(예: 닉네임만 성공) 부모 상태를 먼저 갱신한 뒤 오류를 표시한다.
    private func finishWithError(_ error: Error, partial: UserMeResponse? = nil) {
        isSaving = false
        if let partial { onUpdated(partial.toUserProfile()) }
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    /// 업로드 전 이미지를 최대 변(maxDimension)으로 축소해 메모리/업로드 용량을 제한한다.
    private static func downsampled(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
