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
    @Published var selectedMenuTab: MenuTab = .safe

    var totalSafeMenuCount: Int {
        safeMenuInfos.reduce(0) { $0 + $1.safeMenuCount }
    }

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
                Menu(
                    id: "1",
                    name: "아보카도 셔핑 브레드",
                    price: 12500,
                    description: nil,
                    ingredients: ["아보카도", "빵", "토마토"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 95%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "2",
                    name: "그라브락스 연어 샐러드",
                    price: 25500,
                    description: nil,
                    ingredients: ["연어", "샐러드", "올리브"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 80%", "쇠고기 미포함 가능성 98%", "돼지"]
                )
            ]
        } else {
            return [
                Menu(
                    id: "3",
                    name: "아보카도 셔핑 브레드",
                    price: 12500,
                    description: nil,
                    ingredients: ["아보카도", "빵", "토마토"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 95%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "4",
                    name: "그라브락스 연어 샐러드",
                    price: 25500,
                    description: nil,
                    ingredients: ["연어", "샐러드", "올리브"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 80%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "5",
                    name: "토마토 파스타",
                    price: 15000,
                    description: nil,
                    ingredients: ["파스타", "토마토", "바질"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 90%", "쇠고기 미포함 가능성 95%"]
                )
            ]
        }
    }
}
