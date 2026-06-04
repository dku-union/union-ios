import SwiftUI

// MARK: - Report Sheet

/// 미니앱 신고 시트. 사유 선택 + 선택적 상세 입력 후 `POST /reports` 로 접수한다.
/// App Store 1.2(사용자 생성 콘텐츠 신고 수단) 대응 — 미니앱 호스트에서 호출.
struct ReportSheet: View {
    let miniAppId: Int
    let miniAppName: String

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason?
    @State private var detail: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    private let detailLimit = 1000

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    submittedSection
                } else {
                    reasonSection
                    detailSection
                }
            }
            .navigationTitle("신고하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSubmit ? "닫기" : "취소") { dismiss() }
                }
                if !didSubmit {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Button("제출") { submit() }
                                .disabled(selectedReason == nil)
                        }
                    }
                }
            }
            .alert("신고 실패", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(UNColor.interactive)
    }

    // MARK: - Sections

    private var reasonSection: some View {
        Section {
            ForEach(ReportReason.allCases) { reason in
                Button {
                    selectedReason = reason
                } label: {
                    HStack {
                        Text(reason.displayName)
                            .foregroundStyle(UNColor.textPrimary)
                        Spacer()
                        if selectedReason == reason {
                            Image(systemName: "checkmark")
                                .foregroundStyle(UNColor.interactive)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        } header: {
            Text("‘\(miniAppName)’ 신고 사유")
        }
    }

    private var detailSection: some View {
        Section {
            TextField("자세한 내용을 입력해주세요 (선택)", text: $detail, axis: .vertical)
                .lineLimit(3...6)
                .onChange(of: detail) { _, newValue in
                    if newValue.count > detailLimit {
                        detail = String(newValue.prefix(detailLimit))
                    }
                }
        } header: {
            Text("상세 설명")
        } footer: {
            Text("\(detail.count)/\(detailLimit) · 신고 내용은 운영팀이 검토합니다.")
        }
    }

    private var submittedSection: some View {
        Section {
            VStack(spacing: UNSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(UNColor.success)
                Text("신고가 접수되었습니다")
                    .font(UNFont.headingSmall())
                    .foregroundStyle(UNColor.textPrimary)
                Text("운영팀이 검토 후 조치합니다. 소중한 제보 감사합니다.")
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UNSpacing.lg)
        }
    }

    // MARK: - Submit

    private func submit() {
        guard let reason = selectedReason, !isSubmitting else { return }
        isSubmitting = true
        Task {
            do {
                try await ReportClient.liveValue.reportMiniApp(miniAppId, reason, detail)
                isSubmitting = false
                didSubmit = true
            } catch {
                isSubmitting = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
