# P2P 기록 공유 기능 - 요구사항 명세서

## 개요

Wander 사용자 간 여행 기록을 공유하는 기능입니다. 앱의 서버리스 철학을 유지하면서 P2P 방식으로 기록을 주고받을 수 있습니다.

---

## 핵심 요구사항 (EARS 형식)

### REQ-001: 기록 공유 시작
**When** 사용자가 기록 상세 화면에서 "Wander 공유" 버튼을 탭하면,
**the system shall** 공유 옵션 시트를 표시하고 공유 링크를 생성할 수 있어야 한다.

### REQ-002: 공유 링크 생성
**When** 사용자가 공유 옵션을 설정하고 "링크 생성"을 탭하면,
**the system shall** 다음 정보를 포함한 고유 공유 링크를 생성해야 한다:
- 공유 데이터 패키지 (암호화)
- 만료 시간 정보
- 접근 토큰

### REQ-003: 사진 해상도 옵션
**When** 공유 옵션을 설정할 때,
**the system shall** 다음 사진 해상도 옵션을 제공해야 한다:
- 원본 (Original): 원본 해상도 그대로
- 최적화 (Optimized): 2048px 기준 리사이즈 (용량 절감)

### REQ-004: 메타데이터 포함
**When** 기록을 공유할 때,
**the system shall** 모든 메타데이터를 필수로 포함해야 한다:
- GPS 좌표, 촬영 시간
- 장소명, 주소
- 활동 라벨
- AI 스토리 (있는 경우)

### REQ-005: 링크 만료 설정
**When** 공유 링크를 생성할 때,
**the system shall** 다음 만료 옵션을 제공해야 한다:
- 1일, 7일, 30일
- 영구 (만료 없음)

### REQ-006: 공유 링크 전달
**When** 공유 링크가 생성되면,
**the system shall** 다음 방법으로 링크를 전달할 수 있어야 한다:
- 시스템 공유 시트 (연락처, 메시지, 카카오톡 등)
- 클립보드 복사

### REQ-007: 공유 링크 수신 (Deep Link)
**When** 다른 사용자가 Wander 공유 링크를 탭하면,
**the system shall** Wander 앱을 열고 공유 데이터를 불러와야 한다.

### REQ-008: 공유 기록 저장
**When** 공유 기록을 수신하면,
**the system shall** 다음을 수행해야 한다:
- 공유 기록 미리보기 표시
- "저장" 버튼으로 내 기록에 추가
- "공유됨" 표시와 함께 기록 목록에 표시

### REQ-009: 공유 표시 UI
**When** 공유받은 기록이 기록 목록에 표시될 때,
**the system shall** 썸네일 또는 적절한 위치에 "공유됨" 배지를 표시해야 한다.

### REQ-010: 읽기 전용 권한
**When** 공유받은 기록을 열람할 때,
**the system shall** 다음을 제한해야 한다:
- 편집 불가 (제목, 카테고리 등)
- 삭제만 가능 (내 기록 목록에서)
- 원본 공유자 정보 표시

### REQ-011: 온라인 전용
**When** 공유 링크를 생성하거나 수신할 때,
**the system shall** 네트워크 연결이 필요하며, 오프라인 시 적절한 에러를 표시해야 한다.

---

## 비기능 요구사항

### NFR-001: 보안
- 공유 데이터는 AES-256 암호화 적용
- 링크에 포함된 토큰으로만 복호화 가능
- 만료된 링크는 접근 불가

### NFR-002: 성능
- 공유 링크 생성: 5초 이내
- 공유 데이터 다운로드: 사진 수에 비례 (Wi-Fi 기준)

### NFR-003: 서버리스 제약
- 자체 서버 없이 구현
- 3rd party 클라우드 스토리지 활용 (CloudKit, Firebase Storage 등)
- 또는 데이터 URL 방식 (소용량 한정)

### NFR-004: 데이터 크기
- 원본 사진 포함 시 최대 100MB
- 최적화 사진 포함 시 최대 30MB

---

## 제외 범위 (Out of Scope)

- 실시간 동기화 (한 번 공유 후 업데이트 없음)
- 공유 기록 편집 권한
- 다수에게 동시 공유 (1:1 공유만)
- 오프라인 공유

---

## 용어 정의

| 용어 | 설명 |
|------|------|
| 공유자 (Sender) | 기록을 공유하는 사용자 |
| 수신자 (Receiver) | 공유 링크를 받아 기록을 저장하는 사용자 |
| 공유 패키지 | 기록 데이터 + 사진 + 메타데이터를 압축/암호화한 번들 |
| Deep Link | 앱을 직접 여는 URL (wander:// 또는 Universal Link) |

---

## 참고 자료

- iOS Universal Links: https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content
- Custom URL Schemes: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
- CloudKit Sharing: https://developer.apple.com/documentation/cloudkit/shared_records

---

*작성일: 2026-02-05*
*버전: 1.0*
