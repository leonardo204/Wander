import Foundation
import SwiftData
import CoreLocation
import SwiftyH3

/// 자동 학습된 장소 패턴 (v3.2: HoWDe 비율 기반 + H3 ID)
/// HoWDe 알고리즘 (MIT, Home 97%, Work 88% 정확도) 기반
/// 슬라이딩 윈도우 내 방문 비율로 집/회사/학교를 추론
@Model
final class LearnedPlace {
    var id: UUID

    // MARK: - H3 셀 ID (장소 고유 식별자)

    /// H3 resolution 9 (~0.11 km², 건물 수준) - 장소 유니크 키
    var h3CellRes9: String

    /// H3 resolution 7 (~5.16 km², 동네 수준) - Context Classification 비교용
    var h3CellRes7: String

    /// H3 resolution 5 (~253 km², 시/군 수준)
    var h3CellRes5: String

    /// H3 resolution 4 (~1,770 km², 시/도 수준)
    var h3CellRes4: String

    // MARK: - 표시용 정보 (CLGeocoder 캐시)

    var latitude: Double
    var longitude: Double

    /// 표시용 주소 (예: "서울 강남구 역삼동")
    var displayName: String?

    // MARK: - HoWDe 방문 패턴 (비율 기반)

    /// 방문 날짜 로그 (ISO 8601 JSON 배열, 90일 제한)
    /// 슬라이딩 윈도우 재계산에 사용
    var visitLogJSON: String?

    /// 전체 방문 일수 (중복 제거)
    var totalVisitDays: Int

    /// 야간 방문 일수 (20:00~05:00)
    var nightVisitDays: Int

    /// 평일 주간 방문 일수 (월~금, 09:00~18:00)
    var weekdayDaytimeVisitDays: Int

    /// 윈도우 전체 일수 (비율 분모)
    var windowTotalDays: Int

    /// 첫 관측일
    var firstVisitDate: Date

    /// 마지막 관측일
    var lastVisitDate: Date

    // MARK: - 추천 상태

    /// AI가 추천하는 장소 유형
    var suggestedTypeRaw: String?

    /// 사용자가 확인했는지 여부
    var isConfirmed: Bool

    /// 사용자가 무시했는지 여부
    var isIgnored: Bool

    /// 추천 신뢰도 (0.0~1.0)
    var confidence: Double

    // MARK: - HoWDe 상수

    /// 집 감지 윈도우 크기 (일)
    private static let homeWindowDays = 28

    /// 회사/학교 감지 윈도우 크기 (일)
    private static let workWindowDays = 42

    /// 최대 로그 보관 기간 (일) - 가장 큰 윈도우 + 여유
    private static let maxLogRetentionDays = 90

    /// 집 야간 방문 비율 임계값
    private static let homeNightThreshold = 0.3

    /// 회사 평일 주간 방문 비율 임계값
    private static let workDaytimeThreshold = 0.25

    /// 집 추천 최소 데이터 일수
    private static let homeMinDataDays = 7

    /// 회사 추천 최소 데이터 일수
    private static let workMinDataDays = 14

    // MARK: - Computed Properties

    var suggestedType: UserPlaceType? {
        get {
            guard let raw = suggestedTypeRaw else { return nil }
            return UserPlaceType(rawValue: raw)
        }
        set {
            suggestedTypeRaw = newValue?.rawValue
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// HoWDe 야간 방문 비율 (0.0~1.0)
    var nightVisitProportion: Double {
        guard windowTotalDays > 0 else { return 0 }
        return Double(nightVisitDays) / Double(windowTotalDays)
    }

    /// HoWDe 평일 주간 방문 비율 (0.0~1.0)
    var weekdayDaytimeProportion: Double {
        guard windowTotalDays > 0 else { return 0 }
        return Double(weekdayDaytimeVisitDays) / Double(windowTotalDays)
    }

    /// HoWDe: 집으로 추천할 수 있는지
    /// 28일 윈도우 내 야간 방문 비율 > 30%, 최소 7일 데이터
    var canSuggestAsHome: Bool {
        nightVisitProportion > Self.homeNightThreshold &&
        windowTotalDays >= Self.homeMinDataDays
    }

    /// HoWDe: 회사로 추천할 수 있는지
    /// 42일 윈도우 내 평일 주간 방문 비율 > 25%, 최소 14일 데이터
    var canSuggestAsWork: Bool {
        weekdayDaytimeProportion > Self.workDaytimeThreshold &&
        windowTotalDays >= Self.workMinDataDays
    }

    /// 표시용 위치 요약
    var locationSummary: String {
        displayName ?? "(\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude)))"
    }

    // MARK: - Init

    init(
        coordinate: CLLocationCoordinate2D
    ) {
        self.id = UUID()
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude

        // H3 셀 인덱스 계산 (SwiftyH3: coordinate → H3LatLng → cell)
        let h3LatLng = coordinate.h3LatLng
        self.h3CellRes9 = (try? h3LatLng.cell(at: .res9).description) ?? ""
        self.h3CellRes7 = (try? h3LatLng.cell(at: .res7).description) ?? ""
        self.h3CellRes5 = (try? h3LatLng.cell(at: .res5).description) ?? ""
        self.h3CellRes4 = (try? h3LatLng.cell(at: .res4).description) ?? ""

        self.totalVisitDays = 0
        self.nightVisitDays = 0
        self.weekdayDaytimeVisitDays = 0
        self.windowTotalDays = 0
        self.firstVisitDate = Date()
        self.lastVisitDate = Date()
        self.isConfirmed = false
        self.isIgnored = false
        self.confidence = 0.0
    }

    // MARK: - Methods

    /// 방문 기록 추가 및 HoWDe 윈도우 재계산
    func recordVisit(at date: Date) {
        // 방문 로그에 추가
        var visitDates = loadVisitLog()
        visitDates.append(date)
        lastVisitDate = date
        if visitDates.count == 1 {
            firstVisitDate = date
        }

        // 90일 이전 데이터 트리밍
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.maxLogRetentionDays, to: Date()) ?? Date()
        visitDates = visitDates.filter { $0 > cutoff }
        saveVisitLog(visitDates)

        // HoWDe 윈도우 재계산
        recomputeWindow(visitDates: visitDates)
        updateSuggestion()
    }

    /// HoWDe 슬라이딩 윈도우 재계산
    /// - 집: 최근 28일 윈도우
    /// - 회사: 최근 42일 윈도우
    private func recomputeWindow(visitDates: [Date]) {
        let calendar = Calendar.current
        let now = Date()
        let windowSize = max(Self.homeWindowDays, Self.workWindowDays) // 42일
        let windowStart = calendar.date(byAdding: .day, value: -windowSize, to: now) ?? now

        let windowDates = visitDates.filter { $0 > windowStart }

        // 중복 날짜 제거 (같은 날 여러 방문 → 1일로 카운트)
        let uniqueDays = Set(windowDates.map { calendar.startOfDay(for: $0) })
        totalVisitDays = uniqueDays.count

        // 윈도우 전체 일수 계산
        let daysSinceFirstVisit = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstVisitDate), to: calendar.startOfDay(for: now)).day ?? 0
        windowTotalDays = min(windowSize, max(1, daysSinceFirstVisit + 1))

        // 야간 방문 일수 (20:00~05:00)
        let nightDays = Set(windowDates.filter { date in
            let hour = calendar.component(.hour, from: date)
            return hour >= 20 || hour < 5
        }.map { calendar.startOfDay(for: $0) })
        nightVisitDays = nightDays.count

        // 평일 주간 방문 일수 (월~금, 09:00~18:00)
        let weekdayDaytimeDays = Set(windowDates.filter { date in
            let hour = calendar.component(.hour, from: date)
            let weekday = calendar.component(.weekday, from: date)
            let isWeekday = weekday >= 2 && weekday <= 6
            return isWeekday && hour >= 9 && hour < 18
        }.map { calendar.startOfDay(for: $0) })
        weekdayDaytimeVisitDays = weekdayDaytimeDays.count
    }

    /// HoWDe 추천 유형 업데이트
    /// 우선순위: 집 > 회사 > 학교
    private func updateSuggestion() {
        if canSuggestAsHome {
            suggestedType = .home
            confidence = min(1.0, nightVisitProportion / 0.6) // 0.6 비율이면 100% 신뢰
        } else if canSuggestAsWork {
            suggestedType = .work
            confidence = min(1.0, weekdayDaytimeProportion / 0.5)
        } else {
            suggestedType = nil
            confidence = 0.0
        }
    }

    /// H3 res9 기준 장소 매칭
    func matches(h3CellRes9: String) -> Bool {
        self.h3CellRes9 == h3CellRes9
    }

    // MARK: - Visit Log Serialization

    private func loadVisitLog() -> [Date] {
        guard let json = visitLogJSON,
              let data = json.data(using: .utf8),
              let timestamps = try? JSONDecoder().decode([TimeInterval].self, from: data) else {
            return []
        }
        return timestamps.map { Date(timeIntervalSince1970: $0) }
    }

    private func saveVisitLog(_ dates: [Date]) {
        let timestamps = dates.map { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(timestamps),
           let json = String(data: data, encoding: .utf8) {
            visitLogJSON = json
        }
    }
}
