# P2P 기록 공유 기능 - 구현 작업 목록

## 개요

이 문서는 P2P 기록 공유 기능 구현을 위한 단계별 작업 목록입니다.

---

## Phase 1: 기반 인프라 구축

### 1.1 CloudKit 설정
- [x] CloudKit Container 생성 (iCloud.com.zerolive.wander)
- [x] WanderShare RecordType 스키마 정의
  - shareID (String, Queryable, Sortable)
  - encryptedData (Bytes)
  - photos (Asset List)
  - expiresAt (Date/Time, Queryable, Sortable)
  - createdAt (Date/Time, Queryable, Sortable)
  - photoCount (Int64)
- [x] Xcode Capabilities에 CloudKit 추가
- [x] project.yml 업데이트

### 1.2 CloudKit Manager 구현
- [x] `Services/P2PShare/CloudKitManager.swift` 생성
- [x] uploadSharePackage() 구현
- [x] downloadSharePackage() 구현
- [x] deleteShareRecord() 구현
- [x] checkRecordExists() 구현
- [x] 만료 레코드 정리 로직 구현

### 1.3 암호화 서비스 구현
- [x] `Services/P2PShare/EncryptionService.swift` 생성
- [x] generateEncryptionKey() 구현 (256-bit)
- [x] encrypt(data:key:) 구현 (AES-256-GCM)
- [x] decrypt(data:key:) 구현
- [x] encodeKeyForURL() 구현 (Base64URL)
- [x] decodeKeyFromURL() 구현

---

## Phase 2: 공유 패키지 모델

### 2.1 공유 모델 정의
- [x] `Services/P2PShare/P2PShareModels.swift` 생성
- [x] SharePackage 구조체 정의
- [x] SharedTravelRecord 구조체 정의
- [x] SharedTravelDay 구조체 정의
- [x] SharedPlace 구조체 정의
- [x] PhotoReference 구조체 정의
- [x] P2PShareError 에러 타입 정의

### 2.2 TravelRecord 확장
- [x] TravelRecord 모델에 공유 필드 추가
  - isShared: Bool
  - sharedFrom: String?
  - sharedAt: Date?
  - originalShareID: UUID?
- [x] PhotoItem.assetIdentifier Optional 변경, localFilePath 추가

### 2.3 직렬화/역직렬화
- [x] TravelRecord → SharePackage 변환 구현
- [x] SharePackage → TravelRecord 변환 구현
- [x] 사진 데이터 최적화 로직 (원본/최적화)

---

## Phase 3: P2P 공유 서비스

### 3.1 P2PShareService 구현
- [x] `Services/P2PShare/P2PShareService.swift` 생성
- [x] createShareLink() 구현
  - 공유 옵션 처리 (사진 품질, 만료 기간)
  - SharePackage 생성
  - 암호화
  - CloudKit 업로드
  - URL 생성
- [x] receiveShare() 구현
  - CloudKit에서 다운로드
  - 복호화
  - SharePackage 파싱
  - 미리보기 데이터 반환
- [x] saveSharedRecord() 구현
  - SharePackage → TravelRecord 변환
  - SwiftData에 저장
  - 중복 체크

### 3.2 사진 처리
- [x] 사진 리사이즈 로직 (최적화 옵션)
- [x] CKAsset으로 사진 업로드
- [x] CKAsset에서 사진 다운로드
- [x] 로컬 사진 저장 (Documents 디렉토리)

---

## Phase 4: Deep Link 처리

### 4.1 URL Scheme 설정
- [x] Info.plist에 wander:// URL Scheme 추가 (기존 설정 활용)
- [x] project.yml 업데이트

### 4.2 Universal Link 설정 (TODO - 도메인 확보 후)
- [ ] Associated Domains 설정 (applinks:wander.zerolive.com)
- [ ] AASA 파일 준비 (서버 호스팅 필요)
- [ ] Wander.entitlements 주석 해제
> **현재**: Custom URL Scheme (wander://...) 사용
> **TODO**: 도메인 확보 시 Universal Link 활성화

### 4.3 DeepLinkHandler 구현
- [x] `Core/Utilities/DeepLinkHandler.swift` 생성
- [x] URL 파싱 로직 (shareID, encryptionKey 추출)
- [x] WanderApp.swift에서 onOpenURL 처리
- [x] 공유 수신 화면으로 라우팅

---

## Phase 5: UI 구현

### 5.1 공유 옵션 UI
- [x] `Views/P2PShare/P2PShareOptionsView.swift` 생성
- [x] 사진 품질 선택 UI (원본/최적화)
- [x] 링크 만료 선택 UI (1일/7일/30일/영구)
- [x] 링크 생성 버튼

### 5.2 공유 완료 UI
- [x] `Views/P2PShare/P2PShareCompleteView.swift` 생성
- [x] 공유 링크 생성 성공 화면
- [x] 시스템 공유 시트 연동 (카카오톡, 메시지 등)
- [x] 클립보드 복사 기능

### 5.3 공유 수신 UI
- [x] `Views/P2PShare/P2PShareReceiveView.swift` 생성
- [x] 공유 기록 미리보기
- [x] 공유자 정보 표시
- [x] "내 기록에 저장" 버튼
- [x] 로딩/에러 상태 처리

### 5.4 기록 목록 공유 표시
- [x] RecordsView에 공유 배지 표시 로직 추가
- [x] 공유 배지 컴포넌트 (`Views/Shared/SharedBadgeView.swift`)
- [ ] 공유받은 기록 필터/정렬 옵션 (선택적)

### 5.5 기록 상세 공유 버튼
- [x] ResultView에 "Wander 공유" 버튼 추가
- [x] RecordsView 상세 화면에 "Wander 공유" 버튼 추가
- [x] 공유받은 기록에 SharedFromView 표시

---

## Phase 6: 통합 및 테스트

### 6.1 통합
- [x] WanderApp.swift에 Deep Link 핸들러 연결
- [x] 앱 시작 시 만료 레코드 정리 로직 구현
- [x] 네트워크 상태 체크 연동

### 6.2 에러 처리
- [x] 링크 만료 에러 처리
- [x] 복호화 실패 에러 처리
- [x] 네트워크 오류 처리
- [x] 중복 저장 방지
- [x] 저장 공간 부족 처리

### 6.3 테스트 (TODO)
- [ ] 실제 기기에서 CloudKit 연동 테스트
- [ ] 공유 링크 생성/수신 테스트
- [ ] 만료 링크 테스트
- [ ] 대용량 기록 (많은 사진) 테스트

---

## Phase 7: 문서 업데이트

### 7.1 코드 문서화
- [x] 주요 서비스에 주석 추가
- [ ] 상세 API 문서 작성 (선택)

### 7.2 사용자 문서
- [x] CLAUDE.local.md 업데이트
- [x] 폴더 구조 업데이트
- [x] 주요 기능 설명 추가
- [x] tasks.md 체크리스트 업데이트

---

## 파일 구조 (예상)

```
src/
├── Services/
│   └── P2PShare/                    ← 신규 디렉토리
│       ├── P2PShareModels.swift
│       ├── P2PShareService.swift
│       ├── CloudKitManager.swift
│       └── EncryptionService.swift
│
├── Core/
│   └── Utilities/
│       └── DeepLinkHandler.swift    ← 신규
│
├── Views/
│   ├── P2PShare/                    ← 신규 디렉토리
│   │   ├── P2PShareOptionsView.swift
│   │   ├── P2PShareCompleteView.swift
│   │   └── P2PShareReceiveView.swift
│   │
│   └── Shared/
│       └── SharedBadgeView.swift    ← 신규
│
└── Models/SwiftData/
    └── TravelRecord.swift           ← 필드 추가
```

---

## 예상 소요 시간

| Phase | 작업 | 복잡도 |
|-------|------|--------|
| Phase 1 | 기반 인프라 | 높음 |
| Phase 2 | 공유 모델 | 중간 |
| Phase 3 | 공유 서비스 | 높음 |
| Phase 4 | Deep Link | 중간 |
| Phase 5 | UI | 중간 |
| Phase 6 | 통합/테스트 | 중간 |
| Phase 7 | 문서화 | 낮음 |

---

## 의존성

- **CloudKit Framework**: Apple 제공
- **CryptoKit Framework**: Apple 제공 (AES-256-GCM)
- **Universal Link 호스팅**: wander.zerolive.com 도메인 필요

---

## 주의사항

1. **CloudKit 쿼터**: Public Database의 API 호출 제한 확인
2. **AASA 호스팅**: Universal Link를 위해 HTTPS 서버 필요
3. **SwiftData 마이그레이션**: 기존 데이터 호환성 확인
4. **테스트 환경**: CloudKit 개발/프로덕션 환경 분리

---

*작성일: 2026-02-05*
*버전: 1.0*
