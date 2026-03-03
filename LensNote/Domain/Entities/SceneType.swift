//
//  SceneType.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

/// 촬영 장면(씬) 분류.
/// 카메라 어시스트, 스타일 추천, 모델 입력 feature에서 공통으로 사용한다.
public enum SceneType: String, Codable, CaseIterable {
    case portrait
    case landscape
    case cityStreet = "city_street"
    case food
    case night
    case pet
    case etc
}

public extension SceneType {
    /// UI 표시용 한국어 이름.
    var displayNameKR: String {
        switch self {
        case .portrait: return "인물"
        case .landscape: return "풍경"
        case .cityStreet: return "도시/거리"
        case .food: return "음식"
        case .night: return "야간"
        case .pet: return "반려동물"
        case .etc: return "기타"
        }
    }
}
