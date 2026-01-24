//
//  RestaurantDetailViewModel.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import Combine

class RestaurantDetailViewModel: ObservableObject {
    @Published var restaurant: Restaurant
    @Published var selectedPersons: [Person]
    @Published var safeMenuInfos: [SafeMenuInfo]
    @Published var isOperatingHoursExpanded = false
    @Published var expandedPersonIds: Set<String> = []

    init(restaurant: Restaurant = .sample, selectedPersons: [Person] = Person.sample) {
        self.restaurant = restaurant
        self.selectedPersons = selectedPersons
        self.safeMenuInfos = Self.calculateSafeMenus(for: selectedPersons, restaurant: restaurant)
    }

    func toggleOperatingHours() {
        isOperatingHoursExpanded.toggle()
    }

    func togglePersonMenuExpansion(personId: String) {
        if expandedPersonIds.contains(personId) {
            expandedPersonIds.remove(personId)
        } else {
            expandedPersonIds.insert(personId)
        }
    }

    func isPersonMenuExpanded(personId: String) -> Bool {
        expandedPersonIds.contains(personId)
    }

    private static func calculateSafeMenus(for persons: [Person], restaurant: Restaurant) -> [SafeMenuInfo] {
        // 실제로는 AI API를 호출해서 판단하지만, 여기서는 샘플 데이터 사용
        return persons.map { person in
            SafeMenuInfo(
                person: person,
                safeMenuCount: person.name == "철진" ? 2 : 3,
                safeMenus: sampleMenus(for: person)
            )
        }
    }

    private static func sampleMenus(for person: Person) -> [Menu] {
        if person.name == "철진" {
            return [
                Menu(id: "1", name: "마르게리따 피자", price: 18000, description: "신선한 토마토와 모짜렐라", ingredients: ["토마토", "모짜렐라", "바질"], imageUrl: nil),
                Menu(id: "2", name: "까르보나라", price: 16000, description: "크림 파스타", ingredients: ["파스타", "베이컨", "파마산"], imageUrl: nil)
            ]
        } else {
            return [
                Menu(id: "3", name: "토마토 파스타", price: 15000, description: "토마토 소스 파스타", ingredients: ["파스타", "토마토", "올리브"], imageUrl: nil),
                Menu(id: "4", name: "스테이크", price: 32000, description: "안심 스테이크", ingredients: ["소고기", "감자", "버터"], imageUrl: nil),
                Menu(id: "5", name: "샐러드", price: 12000, description: "신선한 샐러드", ingredients: ["양상추", "토마토", "올리브"], imageUrl: nil)
            ]
        }
    }
}
