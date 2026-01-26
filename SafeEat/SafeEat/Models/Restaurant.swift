//
//  Restaurant.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import CoreLocation

struct Restaurant: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let rating: Double
    let distance: String
    let address: String
    let operatingStatus: String
    let operatingHours: [DayOperatingHours]
    let totalMenuCount: Int
    let imageUrl: String?
    let phoneNumber: String?  // 전화번호 추가
    let latitude: Double?  // 위도
    let longitude: Double?  // 경도

    // CLLocationCoordinate2D로 변환
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static let sample = Restaurant(
        id: "1",
        name: "더 테이블",
        category: "이탈리아음식",
        rating: 4.6,
        distance: "고려대역에서 196m",
        address: "서울특별시 성북구 안암로 145",
        operatingStatus: "14:30 브레이크 타임",
        operatingHours: [
            DayOperatingHours(day: "월", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "화", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "수", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "목", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "금", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "토", hours: "11:30 - 21:00", breakTime: "14:30 - 17:30 브레이크타임", lastOrder: "20:00 라스트오더"),
            DayOperatingHours(day: "일", hours: "09:00 - 18:00", breakTime: nil, lastOrder: "17:00 라스트오더")
        ],
        totalMenuCount: 33,
        imageUrl: nil,
        phoneNumber: "02-1234-5678",
        latitude: 37.5836,  // 고려대 근처
        longitude: 127.0587
    )
}

struct DayOperatingHours: Identifiable, Codable {
    let id = UUID()
    let day: String
    let hours: String
    let breakTime: String?
    let lastOrder: String

    // Codable을 위한 커스텀 키 (id 제외)
    enum CodingKeys: String, CodingKey {
        case day, hours, breakTime, lastOrder
    }

    // 디코딩 시 id는 새로 생성
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try container.decode(String.self, forKey: .day)
        self.hours = try container.decode(String.self, forKey: .hours)
        self.breakTime = try container.decodeIfPresent(String.self, forKey: .breakTime)
        self.lastOrder = try container.decode(String.self, forKey: .lastOrder)
    }

    // 일반 생성자
    init(day: String, hours: String, breakTime: String?, lastOrder: String) {
        self.day = day
        self.hours = hours
        self.breakTime = breakTime
        self.lastOrder = lastOrder
    }
}

struct Menu: Identifiable, Codable {
    let id: String
    var restaurantId: String  // 어느 식당의 메뉴인지
    let name: String
    let price: Int
    let description: String?
    var ingredients: [String]  // OCR로 추출한 재료들
    let imageUrl: String?
    var probabilityTags: [String]  // 추가: 확률 태그들
    let contributorId: String?  // 누가 등록했는지
    let createdAt: Date?  // 언제 등록했는지

    // Codable - Firebase 데이터와 호환되도록
    enum CodingKeys: String, CodingKey {
        case id, restaurantId, name, price, description, ingredients, imageUrl, probabilityTags, contributorId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id는 문서 ID 또는 저장된 값 사용
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.restaurantId = try container.decodeIfPresent(String.self, forKey: .restaurantId) ?? ""
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decodeIfPresent(Int.self, forKey: .price) ?? 0
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.probabilityTags = try container.decodeIfPresent([String].self, forKey: .probabilityTags) ?? []
        self.contributorId = try container.decodeIfPresent(String.self, forKey: .contributorId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // OCR로 메뉴 생성할 때 사용하는 생성자
    init(id: String = UUID().uuidString,
         restaurantId: String,
         name: String,
         price: Int,
         description: String? = nil,
         ingredients: [String] = [],
         imageUrl: String? = nil,
         probabilityTags: [String] = [],
         contributorId: String? = nil,
         createdAt: Date? = Date()) {
        self.id = id
        self.restaurantId = restaurantId
        self.name = name
        self.price = price
        self.description = description
        self.ingredients = ingredients
        self.imageUrl = imageUrl
        self.probabilityTags = probabilityTags
        self.contributorId = contributorId
        self.createdAt = createdAt
    }
}

struct Person: Identifiable, Codable {
    let id: String
    let name: String
    let restrictedIngredients: [String]

    static let sample = [
        Person(id: "1", name: "철진", restrictedIngredients: ["우유", "달걀"]),
        Person(id: "2", name: "현진", restrictedIngredients: ["새우", "갑각류", "조개"])
    ]
}

struct SafeMenuInfo: Identifiable {
    let id = UUID()
    let person: Person
    let safeMenuCount: Int
    let safeMenus: [Menu]
}

enum MenuTab {
    case safe    // 안전한 메뉴
    case other   // 그 외 메뉴
}
