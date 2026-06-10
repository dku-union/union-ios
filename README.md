# union-ios

> **Union** 대학생 전용 미니앱 슈퍼앱 플랫폼의 iOS 클라이언트입니다.  
> 단국대학교 캡스톤디자인 프로젝트

---

## 개요

대학교 이메일로 인증한 사용자가 하나의 앱 안에서 다양한 미니앱을 탐색하고 실행할 수 있는 iOS 슈퍼앱입니다. 미니앱은 WebView 위에서 실행되며, Union SDK를 통해 네이티브 기능(인증, 위치, 카메라, 저장소 등)에 접근합니다.

## 기술 스택

| 분류 | 기술 |
|------|------|
| Language | Swift |
| Architecture | TCA (The Composable Architecture) |
| UI | SwiftUI |
| MiniApp Runtime | WKWebView + JavaScript Bridge |
| 의존성 관리 | Swift Package Manager |

## 주요 의존성

- `swift-composable-architecture` — 단방향 상태 관리
- `zipfoundation` — 미니앱 번들 압축/해제

## 프로젝트 구조

```
Union/
├── App/                    # 앱 진입점, 탭 구조
├── Features/
│   ├── Auth/               # 로그인, 회원가입, 이메일 인증
│   ├── Home/               # 홈 피드 (배너, 미니앱 목록, 카테고리)
│   ├── Search/             # 미니앱 검색
│   ├── MiniApp/            # WebView 컨테이너 + Bridge 핸들러
│   │   ├── Bridge/         # Auth, UI, Device, Storage, Network, Analytics 모듈
│   │   └── Analytics/      # 이벤트 수집 및 배치 전송
│   ├── Notifications/      # 알림 목록
│   └── Profile/            # 사용자 프로필
├── Domain/
│   ├── Entities/           # MiniApp, UserProfile, Banner 등 도메인 모델
│   └── Repositories/       # Repository 프로토콜
├── Data/
│   ├── Clients/            # API 클라이언트 (Auth, MiniApp)
│   ├── DataSources/        # Mock 데이터
│   └── DTOs/               # 서버 응답 DTO
└── Core/
    ├── Network/            # APIClient, APIEndpoint, 에러 처리
    ├── Auth/               # JWT 디코더, Keychain, 토큰 관리
    ├── Cache/              # 디스크 캐시, 쿼리 캐시
    ├── Components/         # 공통 UI 컴포넌트
    └── DesignSystem/       # UNButton, UNFormField, Typography 등
```

## 아키텍처

TCA(The Composable Architecture) 기반으로 화면별 Feature 단위로 상태·액션·리듀서를 분리합니다.

```
View → Action → Reducer → State → View
                    ↓
               Effect (API 호출, 네이티브 기능)
```

## 미니앱 Bridge

미니앱(WebView 내 React 앱)이 `postMessage`로 요청을 보내면, 네이티브 Bridge Handler가 각 모듈로 분기합니다.

```
미니앱 JS → Union SDK (postMessage) → BridgeHandler → 각 Module → 네이티브 API
                                                          ↓
미니앱 JS ← Callback (postMessage) ←──────────────────────┘
```

| Bridge 모듈 | 기능 |
|-------------|------|
| `AuthBridgeModule` | 로그인, 프로필 조회, 토큰 발급 |
| `UIBridgeModule` | Toast, Modal, 네비게이션 바 설정 |
| `DeviceBridgeModule` | 위치, QR 스캔, 클립보드, 진동 |
| `StorageBridgeModule` | 미니앱별 격리된 Key-Value 저장소 |
| `NetworkBridgeModule` | mTLS 자동 적용 HTTP 요청 |
| `AnalyticsBridgeModule` | 이벤트 트래킹, 페이지뷰 수집 |

## 시작하기

### 요구사항

- Xcode 15 이상
- iOS 16 이상 (시뮬레이터 또는 실기기)

### 실행

1. 저장소 클론
```bash
git clone https://github.com/dku-union/union-ios.git
cd union-ios
```

2. `Union.xcodeproj` Xcode로 열기
3. Swift Package Manager 의존성 자동 다운로드 대기
4. 시뮬레이터 또는 실기기 선택 후 실행 (`⌘R`)

> 백엔드 API 주소는 `Core/Network/APIConfig.swift`에서 설정합니다.

## 브랜치 전략

```
main        ← 프로덕션 배포
develop     ← 개발 통합
feature/*   ← 기능 개발 (PR → develop)
```
