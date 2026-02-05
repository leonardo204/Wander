# P2P 기록 공유 기능 - 구현 작업 목록

## 개요

이 문서는 P2P 기록 공유 기능 구현을 위한 단계별 작업 목록입니다.

---

## Phase 1: 기반 인프라 구축

### 1.1 CloudKit 설정
- [ ] CloudKit Container 생성 (iCloud.com.zerolive.wander)
- [ ] WanderShare RecordType 스키마 정의
  - shareID (String, Queryable, Sortable)
  - encryptedData (Bytes)
  - photos (Asset List)
  - expiresAt (Date/Time, Queryable, Sortable)
  - createdAt (Date/Time, Queryable, Sortable)
  - photoCount (Int64)
- [ ] Xcode Capabilities에 CloudKit 추가
- [ ] project.yml 업데이트

### 1.2 CloudKit Manager 구현
- [ ] `Services/P2PShare/CloudKitManager.swift` 생성
- [ ] uploadSharePackage() 구현
- [ ] downloadSharePackage() 구현
- [ ] deleteShareRecord() 구현
- [ ] checkRecordExists() 구현
- [ ] 만료 레코드 정리 로직 구현

### 1.3 암호화 서비스 구현
- [ ] `Services/P2PShare/EncryptionService.swift` 생성
- [ ] generateEncryptionKey() 구현 (256-bit)
- [ ] encrypt(data:key:) 구현 (AES-256-GCM)
- [ ] decrypt(data:key:) 구현
- [ ] encodeKeyForURL() 구현 (Base64URL)
- [ ] decodeKeyFromURL() 구현

---

## Phase 2: 공유 패키지 모델

### 2.1 공유 모델 정의
- [ ] `Services/P2PShare/P2PShareModels.swift` 생성
- [ ] SharePackage 구조체 정의
- [ ] SharedTravelRecord 구조체 정의
- [ ] SharedTravelDay 구조체 정의
- [ ] SharedPlace 구조체 정의
- [ ] PhotoReference 구조체 정의
- [ ] P2PShareError 에러 타입 정의

### 2.2 TravelRecord 확장
- [ ] TravelRecord 모델에 공유 필드 추가
  - isShared: Bool
  - sharedFrom: String?
  - sharedAt: Date?
  - originalShareID: UUID?
- [ ] SwiftData 마이그레이션 처리 (필요시)

### 2.3 직렬화/역직렬화
- [ ] TravelRecord → SharePackage 변환 구현
- [ ] SharePackage → TravelRecord 변환 구현
- [ ] 사진 데이터 최적화 로직 (원본/최적화)

---

## Phase 3: P2P 공유 서비스

### 3.1 P2PShareService 구현
- [ ] `Services/P2PShare/P2PShareService.swift` 생성
- [ ] createShareLink() 구현
  - 공유 옵션 처리 (사진 품질, 만료 기간)
  - SharePackage 생성
  - 암호화
  - CloudKit 업로드
  - URL 생성
- [ ] receiveShare() 구현
  - CloudKit에서 다운로드
  - 복호화
  - SharePackage 파싱
  - 미리보기 데이터 반환
- [ ] saveSharedRecord() 구현
  - SharePackage → TravelRecord 변환
  - SwiftData에 저장
  - 중복 체크

### 3.2 사진 처리
- [ ] 사진 리사이즈 로직 (최적화 옵션)
- [ ] CKAsset으로 사진 업로드
- [ ] CKAsset에서 사진 다운로드
- [ ] 로컬 사진 저장 (Documents 디렉토리)

---

## Phase 4: Deep Link 처리

### 4.1 URL Scheme 설정
- [ ] Info.plist에 wander:// URL Scheme 추가
- [ ] project.yml 업데이트

### 4.2 Universal Link 설정
- [ ] Associated Domains 설정 (applinks:wander.zerolive.com)
- [ ] AASA 파일 준비 (서버 호스팅 필요)
- [ ] Info.plist 업데이트

### 4.3 DeepLinkHandler 구현
- [ ] `Core/Utilities/DeepLinkHandler.swift` 생성
- [ ] URL 파싱 로직 (shareID, encryptionKey 추출)
- [ ] WanderApp.swift에서 onOpenURL 처리
- [ ] 공유 수신 화면으로 라우팅

---

## Phase 5: UI 구현

### 5.1 공유 옵션 UI
- [ ] `Views/P2PShare/P2PShareOptionsView.swift` 생성
- [ ] 사진 품질 선택 UI (원본/최적화)
- [ ] 링크 만료 선택 UI (1일/7일/30일/영구)
- [ ] 링크 생성 버튼

### 5.2 공유 완료 UI
- [ ] `Views/P2PShare/P2PShareCompleteView.swift` 생성
- [ ] 공유 링크 생성 성공 화면
- [ ] 시스템 공유 시트 연동 (카카오톡, 메시지 등)
- [ ] 클립보드 복사 기능

### 5.3 공유 수신 UI
- [ ] `Views/P2PShare/P2PShareReceiveView.swift` 생성
- [ ] 공유 기록 미리보기
- [ ] 공유자 정보 표시
- [ ] "내 기록에 저장" 버튼
- [ ] 로딩/에러 상태 처리

### 5.4 기록 목록 공유 표시
- [ ] RecordsView에 공유 배지 표시 로직 추가
- [ ] 공유 배지 컴포넌트 (`Views/Shared/SharedBadgeView.swift`)
- [ ] 공유받은 기록 필터/정렬 옵션 (선택적)

### 5.5 기록 상세 공유 버튼
- [ ] ResultView에 "Wander 공유" 버튼 추가
- [ ] RecordsView 상세 화면에 "Wander 공유" 버튼 추가
- [ ] SharedRecordView에서 편집 비활성화 (읽기 전용)

---

## Phase 6: 통합 및 테스트

### 6.1 통합
- [ ] WanderApp.swift에 Deep Link 핸들러 연결
- [ ] 앱 시작 시 만료 레코드 정리
- [ ] 네트워크 상태 체크 연동

### 6.2 에러 처리
- [ ] 링크 만료 에러 처리
- [ ] 복호화 실패 에러 처리
- [ ] 네트워크 오류 처리
- [ ] 중복 저장 방지
- [ ] 저장 공간 부족 처리

### 6.3 테스트
- [ ] 공유 링크 생성 테스트
- [ ] 공유 링크 수신 테스트
- [ ] 만료 링크 테스트
- [ ] 대용량 기록 (많은 사진) 테스트
- [ ] 네트워크 불안정 상황 테스트

---

## Phase 7: 문서 업데이트

### 7.1 코드 문서화
- [ ] 모든 public API에 DocC 주석 추가
- [ ] 서비스 계층 README 작성

### 7.2 사용자 문서
- [ ] CLAUDE.local.md 업데이트
- [ ] 폴더 구조 업데이트
- [ ] 주요 기능 설명 추가

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
