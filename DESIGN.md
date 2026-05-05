# Union iOS Design System (SwiftUI)

Union iOS 앱의 디자인 시스템 명세서. Web 대시보드 DESIGN.md와 동일한 브랜드 아이덴티티를 공유하며, SwiftUI 네이티브 패턴으로 구현한다.

> **Source of Truth**: `union-dashboard/DESIGN.md`의 3-color brand palette (Ice / Charcoal / Union Red)
> **구현 위치**: `Union/Core/DesignSystem/`

---

## Color Palette

Huemint 기반 3-color 브랜드 팔레트. 깔끔하고 모던한 느낌에 강렬한 액센트.

> Reference: https://huemint.com/brand-2/#palette=edf2fa-262725-e83a33

### Core Colors

| Role | Name | Hex | SwiftUI | Usage |
|------|------|-----|---------|-------|
| **Background** | Ice | `#EDF2FA` | `Color(hex: "EDF2FA")` | 페이지 배경, 카드 배경, 밝은 영역 |
| **Dark** | Charcoal | `#262725` | `Color(hex: "262725")` | 텍스트, 헤더, 다크 섹션 배경, 아이콘 |
| **Accent** | Union Red | `#E83A33` | `Color(hex: "E83A33")` | CTA 버튼, 하이라이트, 뱃지 |

### Extended Palette

```swift
// MARK: - Ice Scale (Background family)
static let ice50  = Color(hex: "F7F9FD")  // 가장 밝은 배경
static let ice100 = Color(hex: "EDF2FA")  // Base Background
static let ice200 = Color(hex: "DCE4F2")  // Divider, 비활성 영역
static let ice300 = Color(hex: "C5D1E8")  // Placeholder, disabled

// MARK: - Charcoal Scale (Dark family)
static let charcoal900 = Color(hex: "262725")  // Base Dark (본문 텍스트)
static let charcoal800 = Color(hex: "363836")  // 헤딩, 강조 텍스트
static let charcoal700 = Color(hex: "4A4C4A")  // 서브텍스트
static let charcoal600 = Color(hex: "6B6D6B")  // 캡션, 힌트 텍스트
static let charcoal500 = Color(hex: "8E908E")  // 비활성 아이콘
static let charcoal400 = Color(hex: "B0B2B0")  // 테두리, 구분선

// MARK: - Red Scale (Accent family)
static let red600 = Color(hex: "C42E29")  // 버튼 hover/pressed
static let red500 = Color(hex: "E83A33")  // Base Accent (CTA, 하이라이트)
static let red400 = Color(hex: "EF6560")  // 소프트 액센트, 태그
static let red300 = Color(hex: "F4908C")  // 알림 뱃지 배경
static let red200 = Color(hex: "FACCCB")  // 밝은 액센트 배경
static let red100 = Color(hex: "FDE8E7")  // 에러 배경, 서브 하이라이트
```

### Semantic Colors

```swift
enum UNColor {
    // MARK: - Background
    static let bgPrimary    = ice100       // 기본 페이지 배경
    static let bgSecondary  = Color.white  // 카드, 모달
    static let bgDark       = charcoal900  // 다크 섹션 (푸터, 히어로)
    static let bgAccent     = red100       // 액센트 하이라이트 배경
    static let bgPressed    = ice200       // 탭 프레스 상태

    // MARK: - Text
    static let textPrimary   = charcoal900  // 본문 텍스트
    static let textSecondary = charcoal600  // 보조 텍스트, 캡션
    static let textTertiary  = charcoal500  // 비활성 텍스트
    static let textOnDark    = ice100       // 다크 배경 위 텍스트
    static let textAccent    = red500       // 하이라이트 텍스트, 링크

    // MARK: - Border & Divider
    static let border       = ice200       // 기본 테두리
    static let borderStrong = charcoal400  // 강조 테두리
    static let divider      = ice200       // 구분선

    // MARK: - Interactive
    static let interactive      = red500   // CTA 버튼, 주요 인터랙션
    static let interactiveHover = red600   // Pressed 상태

    // MARK: - Status
    static let success    = Color(hex: "2D8A4E")  // 성공
    static let warning    = Color(hex: "D4860A")  // 경고
    static let error      = Color(hex: "DC2626")  // 에러 (브랜드 Red와 구분되는 System Red 계열)
    // ⚠️ interactive(#E83A33)와 error(#DC2626)는 의도적으로 다른 색상.
    // 에러 상태에서는 반드시 아이콘(exclamationmark.circle.fill) 병행 필수.

    // MARK: - Gradient
    static let gradientAccent = LinearGradient(
        colors: [red500, red400],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

### Color Accessibility

| Combination | Contrast Ratio | WCAG |
|-------------|---------------|------|
| Charcoal on Ice | 13.8:1 | AAA |
| White on Union Red | 4.6:1 | AA |
| Charcoal on White | 15.4:1 | AAA |
| Union Red on White | 4.5:1 | AA (Large) |

---

## Typography

### Font Stack

```swift
enum UNFont {
    /// Primary: SF Pro (시스템 기본)
    /// 한국어 최적화: Apple SD Gothic Neo (시스템 자동 폴백)
    /// Monospace: SF Mono

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}
```

### Type Scale

| Token | Size | Weight | Design | Usage |
|-------|------|--------|--------|-------|
| `displayLarge` | 34pt | Bold | Rounded | 히어로 타이틀 |
| `displayMedium` | 28pt | Bold | Rounded | 섹션 타이틀 |
| `displaySmall` | 24pt | Bold | Rounded | 페이지 타이틀 |
| `headingLarge` | 20pt | Bold | Default | 카드/섹션 제목 |
| `headingMedium` | 18pt | Semibold | Default | 서브섹션 제목 |
| `headingSmall` | 16pt | Semibold | Default | 소제목 |
| `bodyLarge` | 16pt | Regular | Default | 본문 |
| `bodyMedium` | 14pt | Regular | Default | 보조 텍스트 |
| `bodySmall` | 13pt | Regular | Default | 설명, 캡션 |
| `captionLarge` | 12pt | Medium | Default | 메타 정보 |
| `captionSmall` | 11pt | Medium | Default | 힌트, 타임스탬프 |
| `labelLarge` | 16pt | Semibold | Default | 버튼 (Large) |
| `labelMedium` | 14pt | Semibold | Default | 버튼 (Medium) |
| `labelSmall` | 12pt | Semibold | Default | 버튼 (Small), 태그 |

### Dynamic Type 지원

```swift
// ✅ 추천: 시스템 텍스트 스타일 사용
.font(.body)

// ✅ 추천: 커스텀 크기 + relativeTo로 자동 스케일링
.font(.system(size: 20, weight: .bold).leading(.tight))
// 또는
.font(.custom("SF Pro", size: 20, relativeTo: .title3))

// ✅ 레이아웃 요소에는 @ScaledMetric
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24

// ❌ 비추천: 고정 크기
.font(.system(size: 16))
```

| Design Token | Dynamic Type Style | Scales With |
|--------------|--------------------|-------------|
| displayLarge | `.largeTitle` | Accessibility sizes |
| headingLarge | `.title3` | Accessibility sizes |
| bodyLarge | `.body` | All sizes |
| bodyMedium | `.subheadline` | All sizes |
| captionLarge | `.caption` | All sizes |
| labelMedium | `.callout` | All sizes |

---

## Spacing & Layout

### Spacing Scale (4pt base)

```swift
enum UNSpacing {
    static let none:   CGFloat = 0
    static let xs:     CGFloat = 4    // space-1
    static let sm:     CGFloat = 8    // space-2
    static let md:     CGFloat = 12   // space-3
    static let lg:     CGFloat = 16   // space-4
    static let xl:     CGFloat = 20   // space-5
    static let xxl:    CGFloat = 24   // space-6
    static let xxxl:   CGFloat = 32   // space-8
    static let xxxxl:  CGFloat = 40   // space-10
    static let jumbo:  CGFloat = 48   // space-12
    static let mega:   CGFloat = 64   // space-16
}
```

### Border Radius

```swift
enum UNRadius {
    static let sm:   CGFloat = 8    // 태그, 뱃지, 작은 요소
    static let md:   CGFloat = 12   // 카드, 입력 필드
    static let lg:   CGFloat = 16   // 모달, 큰 카드
    static let xl:   CGFloat = 20   // 히어로 카드, 배너
    static let xxl:  CGFloat = 24   // 바텀 시트
    static let full: CGFloat = 100  // 아바타, 원형 버튼
}
```

### Safe Area & Screen Margins

```swift
// 화면 가장자리 기본 패딩
static let screenHorizontalPadding: CGFloat = UNSpacing.lg  // 16pt
static let screenVerticalPadding: CGFloat = UNSpacing.xl    // 20pt

// Safe Area 대응
.safeAreaInset(edge: .bottom) { ... }
.ignoresSafeArea(.container, edges: .top)  // 히어로 섹션
```

### Content Width

```swift
// 컨텐츠 최대 너비 (iPad 대응)
static let maxContentWidth: CGFloat = 560  // iPhone에서는 의미 없음, iPad에서 제한
```

---

## Shadow System

```swift
enum UNShadow {
    /// 카드 기본 그림자
    static let card = ShadowStyle(
        color: Color(hex: "262725").opacity(0.06),
        radius: 12,
        x: 0, y: 4
    )

    /// 떠오른 요소 (모달, 팝오버)
    static let elevated = ShadowStyle(
        color: Color(hex: "262725").opacity(0.10),
        radius: 20,
        x: 0, y: 8
    )

    /// 미묘한 그림자 (인풋, 태그)
    static let subtle = ShadowStyle(
        color: Color(hex: "262725").opacity(0.04),
        radius: 6,
        x: 0, y: 2
    )

    /// 강한 그림자 (플로팅 버튼, 바텀 시트)
    static let strong = ShadowStyle(
        color: Color(hex: "262725").opacity(0.12),
        radius: 32,
        x: 0, y: 8
    )
}

// Usage:
.shadow(color: UNShadow.card.color, radius: UNShadow.card.radius, x: 0, y: 4)

// ViewModifier 방식
.unShadow(.card)
.unShadow(.elevated)
```

---

## Iconography (SF Symbols)

### 기본 규칙

```swift
// Rendering Mode
Image(systemName: "house.fill")
    .symbolRenderingMode(.hierarchical)  // 기본: 단색 계층
    .foregroundStyle(UNColor.interactive)

// Palette mode (2색 이상)
Image(systemName: "person.crop.circle.badge.checkmark")
    .symbolRenderingMode(.palette)
    .foregroundStyle(UNColor.interactive, UNColor.textSecondary)
```

### 크기 매핑

| Context | Size | Weight | 사용처 |
|---------|------|--------|--------|
| TabBar | 24pt | .regular | 탭 바 아이콘 |
| Navigation | 20pt | .medium | 네비게이션 버튼 |
| Inline | 16pt | .regular | 텍스트 옆 아이콘 |
| Card Action | 20pt | .regular | 카드 내 액션 버튼 |
| Empty State | 48pt | .light | 빈 상태 일러스트 |
| Badge | 12pt | .medium | 뱃지, 상태 아이콘 |

### 자주 쓰는 심볼

```
Navigation: chevron.left, xmark, ellipsis, magnifyingglass
Actions:    plus, pencil, trash, square.and.arrow.up
Status:     checkmark.circle.fill, exclamationmark.circle.fill, clock
Tab:        house.fill, magnifyingglass, clock.arrow.circlepath, bell.fill, person.fill
```

---

## Material & Blur Effects

```swift
// TabBar 배경
.background(.ultraThinMaterial)

// NavigationBar (스크롤 시)
.background(.regularMaterial)

// 바텀 시트 배경
.background(.thickMaterial)

// 오버레이 (모달 뒤)
Color.black.opacity(0.3)
    .ignoresSafeArea()
```

| Effect | 사용처 |
|--------|--------|
| `.ultraThinMaterial` | TabBar, 플로팅 버튼 배경 |
| `.regularMaterial` | NavigationBar (scrolled) |
| `.thickMaterial` | 바텀 시트 |
| `.ultraThickMaterial` | 사용하지 않음 |

---

## Haptic Feedback

```swift
// 버튼 탭
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// 성공 완료
UINotificationFeedbackGenerator().notificationOccurred(.success)

// 에러 발생
UINotificationFeedbackGenerator().notificationOccurred(.error)

// 토글/선택 변경
UISelectionFeedbackGenerator().selectionChanged()
```

| Event | Haptic | 강도 |
|-------|--------|------|
| 버튼 탭 | Impact (.light) | 약 |
| 중요 액션 완료 | Notification (.success) | 중 |
| 에러/실패 | Notification (.error) | 강 |
| 토글/스위치 | Selection | 미약 |
| Pull to refresh | Impact (.medium) | 중 |
| 삭제 확인 | Notification (.warning) | 중 |

---

## Component Patterns

### Style Protocol 구현 규칙

SwiftUI 네이티브 Style Protocol을 사용한다. 커스텀 래퍼 뷰보다 Style을 우선한다.

```swift
// ✅ 좋은 예: ButtonStyle 사용
Button("제출", action: submit)
    .buttonStyle(UNPrimaryButtonStyle(size: .large))

// ✅ 좋은 예: 축약 dot syntax
Button("제출", action: submit)
    .buttonStyle(.unPrimary)

// ❌ 나쁜 예: 커스텀 래퍼 뷰
UNButton(title: "제출", action: submit)  // 환경 전파 깨짐
```

### Buttons

```
UNPrimaryButton (CTA)
  Background: UNColor.interactive (#E83A33)
  Text: .white
  Pressed: UNColor.interactiveHover (#C42E29), opacity 0.85, scale 0.98
  Radius: UNRadius.md (12pt)
  Height: Large 52pt / Medium 44pt / Small 34pt
  Font: labelLarge / labelMedium / labelSmall
  Min touch target: 44x44pt (HIG 가이드)

UNSecondaryButton
  Background: .clear
  Border: 1.5pt UNColor.interactive
  Text: UNColor.interactive
  Pressed: UNColor.bgAccent background

UNGhostButton
  Background: .clear
  Text: UNColor.textSecondary
  Pressed: UNColor.bgPressed background

UNDangerButton
  Background: UNColor.error (#E83A33)
  Text: .white
  Pressed: darker red, opacity 0.85
```

### Cards

```
UNCard (기본)
  Background: .white
  Radius: UNRadius.lg (16pt)
  Shadow: UNShadow.card
  Padding: UNSpacing.xxl (24pt)

UNCard (인터랙티브)
  탭 시: scaleEffect(0.98), 0.15s easeInOut
  Shadow 변화: card → elevated (탭 시)

UNCard (그룹)
  Background: UNColor.bgPrimary (ice)
  Border: 없음
  내부 아이템 구분: UNDivider
```

### Forms & Inputs

```
UNFormField (기본)
  Height: 52pt
  Border: 1pt UNColor.border
  Radius: UNRadius.md (12pt)
  Background: .white
  Text: UNColor.textPrimary
  Placeholder: UNColor.textTertiary

UNFormField (포커스)
  Border: 1.5pt UNColor.interactive
  Animation: 0.2s easeInOut

UNFormField (에러)
  Border: 1.5pt UNColor.error
  Error text: bodySmall, UNColor.error
  아이콘: exclamationmark.circle.fill

UNFormField (비활성)
  Opacity: 0.5
  Background: UNColor.bgPressed (ice-200)
  인터랙션 불가
```

### Navigation

```
TabBar
  Background: .white (또는 .ultraThinMaterial)
  선택: UNColor.interactive 아이콘 + 텍스트
  비선택: UNColor.textTertiary
  구분선: UNColor.divider (상단 1pt)

NavigationBar
  Background: .white (scrolled) / .clear (top)
  Title: headingLarge, UNColor.textPrimary
  Large title: displaySmall
```

### Status Indicators

```swift
enum UNStatusStyle {
    case active    // 녹색: UNColor.success
    case warning   // 노란색: UNColor.warning
    case error     // 빨간색: UNColor.error
    case inactive  // 회색: UNColor.textTertiary
    case review    // 빨간색: UNColor.interactive
}
```

```
Dot indicator: 8pt circle, 상태 색상
Badge: 캡슐 형태, 상태 색상 12% opacity 배경 + 상태 색상 텍스트
```

### Empty States

```
Layout: VStack centered, maxWidth 280pt
Icon: 48pt, UNColor.textTertiary at 50% opacity
Heading: headingMedium, UNColor.textPrimary
Description: bodyMedium, UNColor.textSecondary, multilineTextAlignment .center
CTA: UNPrimaryButton (optional)
Spacing: UNSpacing.lg between elements
```

### Loading States

```
Skeleton (SkeletonRect)
  Background: UNColor.border (ice-200)
  Animation: shimmer (opacity 0.4 → 1.0 → 0.4, 1.5s loop)
  Radius: 대상 요소와 동일하게

ProgressView (시스템)
  Tint: UNColor.interactive
  Large: 32pt / Inline: 20pt
```

---

## Animation & Motion

### Entry Animations

```swift
// Fade Up (페이지 진입, 카드 등장)
.opacity(isVisible ? 1 : 0)
.offset(y: isVisible ? 0 : 16)
.animation(.easeOut(duration: 0.5), value: isVisible)

// Scale In (모달, 팝오버)
.opacity(isVisible ? 1 : 0)
.scaleEffect(isVisible ? 1 : 0.96)
.animation(.easeOut(duration: 0.3), value: isVisible)

// Slide In (사이드바 아이템)
.opacity(isVisible ? 1 : 0)
.offset(x: isVisible ? 0 : -12)
.animation(.easeOut(duration: 0.4), value: isVisible)
```

### Stagger Pattern

```swift
// 리스트/그리드 아이템 순차 등장
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ItemView(item: item)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .animation(
            .easeOut(duration: 0.4).delay(Double(index) * 0.05),
            value: isVisible
        )
}
// 최대 8개 아이템 (400ms max delay)
```

### Interactive Motion

```swift
// 버튼/카드 프레스
.scaleEffect(isPressed ? 0.98 : 1.0)
.opacity(isPressed ? 0.85 : 1.0)
.animation(.easeInOut(duration: 0.15), value: isPressed)

// Spring (바운스 인터랙션)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)

// 자연스러운 전환
.animation(.easeInOut(duration: 0.2), value: state)  // 기본 전환
.animation(.easeOut(duration: 0.3), value: state)     // 느린 전환
```

### Transition Presets

```swift
extension AnyTransition {
    static var fadeUp: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        )
    }

    static var scaleIn: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96))
    }
}
```

### Reduced Motion 지원

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// 사용 예
.animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: isVisible)
.offset(y: reduceMotion ? 0 : (isVisible ? 0 : 16))
```

---

## Scroll & Navigation Behavior

### NavigationBar 전환

```swift
// Large Title → Inline (스크롤 시 자동 축소)
.navigationBarTitleDisplayMode(.large)  // Home, 탭 루트 화면
.navigationBarTitleDisplayMode(.inline) // 상세 화면, 모달

// 스크롤 시 배경 변화
// 상단: .clear → 스크롤 후: .regularMaterial
```

### Pull to Refresh

```swift
List { ... }
    .refreshable {
        await viewModel.refresh()
        // Haptic: Impact (.medium)
    }
```

### Scroll Position 감지

```swift
// iOS 17+ ScrollView with scrollPosition
ScrollView {
    LazyVStack { ... }
}
.scrollTargetLayout()

// iOS 16: GeometryReader 기반 오프셋 감지
```

### 바텀 시트

```swift
.sheet(isPresented: $showSheet) { ... }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(UNRadius.xxl)  // 24pt
```

---

## Accessibility

### Touch Targets

```
최소 터치 영역: 44x44pt (Apple HIG)
버튼 최소 높이:
  Small: 34pt (44pt 터치 영역은 padding으로 확보)
  Medium: 44pt
  Large: 52pt
```

### VoiceOver

```swift
// 필수: 모든 인터랙티브 요소에 접근성 레이블
.accessibilityLabel("앱 이름")
.accessibilityHint("탭하여 앱을 실행합니다")

// 상태 뱃지
.accessibilityLabel("상태: 활성")

// 그룹화
.accessibilityElement(children: .combine)

// 장식 요소 숨김
.accessibilityHidden(true)
```

### Color Contrast

- **Charcoal on Ice**: 13.8:1 (WCAG AAA)
- 색상만으로 상태 표시 금지 — 아이콘 또는 텍스트 레이블 병행
- `accessibilityIgnoresInvertColors` for images

### Dynamic Type

```swift
// ✅ 좋은 예: 시스템 텍스트 스타일 사용
Text("제목").font(.title3)

// ✅ 좋은 예: ScaledMetric으로 커스텀 크기 대응
@ScaledMetric var iconSize: CGFloat = 24

// ❌ 나쁜 예: 고정 크기
Text("제목").font(.system(size: 20))
```

---

## Geometric Motif

Huemint 브랜드 이미지에서 가져온 기하학적 모티프.

### Pattern 요소

| Pattern | 설명 | 사용처 |
|---------|------|--------|
| Quarter Circle | 정사각형 안 1/4 원 | 코너 장식, 섹션 구분 |
| Leaf Shape | 두 개의 1/4 원이 만나 잎 모양 | 브랜드 아이덴티티 |
| Circle in Square | 정사각형에 내접한 원 | 아이콘 프레임, 로고 프레임 |
| Grid Mosaic | 3색으로 채운 정사각형 그리드 | 히어로 배경, 장식 요소 |

### SwiftUI 구현

```swift
// Quarter Circle
Circle()
    .trim(from: 0, to: 0.25)
    .fill(UNColor.interactive)
    .frame(width: 120, height: 120)

// Grid Mosaic (장식 배경)
LazyVGrid(columns: Array(repeating: .init(.fixed(40)), count: 4)) {
    ForEach(0..<16) { i in
        RoundedRectangle(cornerRadius: UNRadius.sm)
            .fill([UNColor.bgPrimary, UNColor.interactive, UNColor.bgDark].randomElement()!)
            .frame(height: 40)
    }
}
.opacity(0.1)
```

### 사용 가이드

- 히어로 섹션 배경 패턴: Grid Mosaic, 10% opacity
- 빈 상태 일러스트: Leaf Shape 조합
- 로딩 스켈레톤: Circle in Square 프레임
- 장식 요소: 항상 `accessibilityHidden(true)` 적용

---

## Dark Mode (향후)

### 구현 방식: Asset Catalog 우선

```swift
// ✅ 추천: Xcode Asset Catalog에 Light/Dark variant 정의
// Assets.xcassets → New Color Set → Appearances: Any, Dark
Color("bgPrimary")  // 자동으로 Light/Dark 전환

// ✅ 대안: @Environment 기반 분기
@Environment(\.colorScheme) var colorScheme
let bg = colorScheme == .dark ? Color(hex: "1A1B1A") : Color(hex: "EDF2FA")

// ❌ 비추천: UIColor traitCollection (UIKit 패턴)
```

| Token | Light | Dark |
|-------|-------|------|
| `bgPrimary` | `#EDF2FA` | `#1A1B1A` |
| `bgSecondary` | `#FFFFFF` | `#262725` |
| `textPrimary` | `#262725` | `#EDF2FA` |
| `textSecondary` | `#6B6D6B` | `#8E908E` |
| `border` | `#DCE4F2` | `#363836` |
| `interactive` | `#E83A33` | `#EF6560` |

---

## Implementation Checklist

### 기존 코드 마이그레이션 (Blue → Red)

현재 `DesignSystem.swift`의 Blue palette (#3B5BFF)를 본 문서의 Red palette (#E83A33)로 전환해야 한다.

```
변경 대상:
  UNColor.brand        → #E83A33 (was #3B5BFF)
  UNColor.brandDark    → #C42E29 (was dark blue)
  UNColor.brandLight   → #FDE8E7 (was light blue)
  Gradient presets      → Red 기반 그라디언트로 교체
  coral/mint/amber/violet semantic colors → 유지 가능 (status용)
```

### 파일 구조

```
Union/Core/DesignSystem/
├── DesignSystem.swift      ← UNColor, UNSpacing, UNRadius, UNShadow
├── UNTypography.swift      ← UNFont, UNTextStyle modifier
├── UNButton.swift          ← Button styles (Primary/Secondary/Ghost/Danger)
├── UNFormField.swift       ← Form fields, secure fields, code input
├── UNComponents.swift      ← Badge, Tag, TextField, Divider, Chip, Card
Union/Core/Components/
├── SkeletonModifier.swift  ← Shimmer animation
├── AppIconView.swift       ← Mini-app icon
└── SectionHeader.swift     ← Section titles with action
```

### Token 매핑 (Web ↔ iOS)

| Web CSS Variable | iOS Token |
|-----------------|-----------|
| `--color-bg-primary` | `UNColor.bgPrimary` |
| `--color-bg-secondary` | `UNColor.bgSecondary` |
| `--color-text-primary` | `UNColor.textPrimary` |
| `--color-text-secondary` | `UNColor.textSecondary` |
| `--color-interactive` | `UNColor.interactive` |
| `--color-border` | `UNColor.border` |
| `--radius-md` | `UNRadius.md` |
| `--space-4` | `UNSpacing.lg` |
| `--shadow-sm` | `UNShadow.subtle` |
| `--shadow-md` | `UNShadow.card` |
| `--shadow-lg` | `UNShadow.elevated` |
| `--shadow-xl` | `UNShadow.strong` |
| `--transition-normal` | `.easeInOut(duration: 0.2)` |
