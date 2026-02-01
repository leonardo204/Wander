# Wander - 버그 수정 목록 (fix.md)

> 단순 버그 수정 또는 간단한 코드 변경으로 해결 가능한 항목

---

## 🔴 Critical (즉시 수정 필요)

### 1. 지금 뭐해 분석중 화면 레이아웃 버그
- **현상**: 분석 중 화면이 좁은 흰색 띠로만 표시되고 양옆이 검은색
- **원인 추정**: fullScreenCover 또는 sheet가 전체 화면을 채우지 못함
- **파일**: `src/Views/QuickMode/QuickModeView.swift`
- **참고**: p1.png 이미지
- **수정 방향**:
  - `.ignoresSafeArea()` 추가 확인
  - 배경색이 제대로 적용되는지 확인
  - sheet/fullScreenCover의 presentationDetents 확인

### 2. 설정 > 데이터 관리에 기록 개수 0개로 표시
- **현상**: 실제 기록이 있는데 0개로 나옴
- **파일**: `src/Views/Settings/SettingsView.swift` (DataManagementView 부분)
- **수정 방향**: @Query로 records 개수를 제대로 가져오는지 확인

---

## 🟡 Medium (빠른 시일 내 수정)

### 3. 앱 정보에서 깃헙 링크 제거
- **현상**: 앱 정보에 깃헙 레포지토리 링크가 표시됨
- **요청**: 제거 필요
- **파일**: `src/Views/Settings/SettingsView.swift` (AppInfoView 부분)
- **수정**: 깃헙 관련 Row/Link 삭제

### 4. 온보딩 다시보기 위치 변경
- **현재**: 설정 메인에 있음
- **변경**: "개발자 모드" 그룹 신설 후 하위 항목으로 이동
- **파일**: `src/Views/Settings/SettingsView.swift`
- **수정 방향**:
  ```swift
  Section("개발자 모드") {
      Button("온보딩 다시보기") { ... }
      // 추후 다른 개발자 옵션 추가 가능
  }
  ```

### 5. 기록 기본 카테고리에 "출장" 추가
- **현재 카테고리**: travel, daily, weekly
- **추가 필요**: business (출장)
- **수정 파일**:
  - `src/Models/SwiftData/TravelRecord.swift` - recordType 관련
  - `src/Views/Records/RecordsView.swift` - RecordFilter enum
  - 기타 카테고리 표시하는 모든 곳

---

## 🟢 Low (여유 있을 때 수정)

### 6. (해당 없음 - 현재 없음)

---

## 수정 체크리스트

- [x] 지금 뭐해 분석중 화면 레이아웃 버그
- [x] 설정 > 데이터 관리 기록 개수 버그
- [x] 앱 정보에서 깃헙 링크 제거
- [x] 온보딩 다시보기 → 개발자 모드 그룹으로 이동
- [x] 기록 카테고리에 "출장" 추가

---

*최종 업데이트: 2026-02-01*
