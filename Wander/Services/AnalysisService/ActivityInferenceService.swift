import Foundation

class ActivityInferenceService {
    func infer(placeType: String?, time: Date?) -> ActivityType {
        let hour = Calendar.current.component(.hour, from: time ?? Date())

        // First, try to infer from place type
        if let type = placeType?.lowercased() {
            if type.contains("cafe") || type.contains("coffee") {
                return .cafe
            }
            if type.contains("restaurant") || type.contains("food") {
                return .restaurant
            }
            if type.contains("beach") || type.contains("sea") {
                return .beach
            }
            if type.contains("mountain") || type.contains("trail") || type.contains("hiking") {
                return .mountain
            }
            if type.contains("airport") {
                return .airport
            }
            if type.contains("museum") || type.contains("gallery") || type.contains("theater") || type.contains("culture") {
                return .culture
            }
            if type.contains("mall") || type.contains("shop") || type.contains("store") || type.contains("shopping") {
                return .shopping
            }
            if type.contains("tourist") || type.contains("park") || type.contains("temple") || type.contains("landmark") {
                return .tourist
            }
        }

        // Fallback: infer from time of day
        switch hour {
        case 6...9:
            // Early morning - likely breakfast or cafe
            return .cafe

        case 10...11:
            // Late morning - could be cafe or tourist spot
            return .cafe

        case 12...14:
            // Lunch time
            return .restaurant

        case 15...17:
            // Afternoon - tourist activities
            return .tourist

        case 18...21:
            // Dinner time
            return .restaurant

        case 22...23, 0...5:
            // Late night / early morning
            return .other

        default:
            return .other
        }
    }

    // Infer activity label for display
    func inferActivityLabel(activityType: ActivityType, time: Date?) -> String {
        let hour = Calendar.current.component(.hour, from: time ?? Date())

        switch activityType {
        case .cafe:
            if hour < 11 {
                return "모닝 커피"
            } else if hour < 15 {
                return "브런치/카페"
            } else {
                return "오후 티타임"
            }

        case .restaurant:
            if hour < 11 {
                return "아침 식사"
            } else if hour < 15 {
                return "점심 식사"
            } else if hour < 18 {
                return "늦은 점심"
            } else {
                return "저녁 식사"
            }

        case .beach:
            return "해변 산책"

        case .mountain:
            return "등산/하이킹"

        case .tourist:
            return "관광"

        case .shopping:
            return "쇼핑"

        case .culture:
            return "문화 활동"

        case .airport:
            return "공항"

        case .other:
            return "방문"
        }
    }
}
