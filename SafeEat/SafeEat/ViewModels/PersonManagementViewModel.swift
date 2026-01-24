//
//  PersonManagementViewModel.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation

@MainActor
class PersonManagementViewModel: ObservableObject {
    @Published var persons: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    // 가능한 모든 알레르기 유발 물질
    let availableAllergens = [
        "우유", "쇠고기", "돼지고기", "닭고기",
        "새우", "갑각류", "조개", "게",
        "달걀", "땅콩", "밀", "대두",
        "고등어", "복숭아", "토마토",
        "아황산류", "호두", "잣", "메밀"
    ]

    init() {
        // 임시 샘플 데이터 로드
        loadSampleData()
    }

    // MARK: - Person CRUD

    func loadPersons(userId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            persons = try await firestoreService.getPersons(userId: userId)
            isLoading = false
        } catch {
            errorMessage = "인물 목록을 불러오는데 실패했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func addPerson(userId: String, name: String, restrictedIngredients: [String]) async {
        let newPerson = Person(
            id: UUID().uuidString,
            name: name,
            restrictedIngredients: restrictedIngredients
        )

        isLoading = true
        errorMessage = nil

        do {
            try await firestoreService.addPerson(userId: userId, person: newPerson)
            persons.append(newPerson)
            isLoading = false
        } catch {
            errorMessage = "인물 추가에 실패했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func updatePerson(userId: String, person: Person) async {
        isLoading = true
        errorMessage = nil

        do {
            try await firestoreService.updatePerson(userId: userId, person: person)

            if let index = persons.firstIndex(where: { $0.id == person.id }) {
                persons[index] = person
            }

            isLoading = false
        } catch {
            errorMessage = "인물 수정에 실패했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func deletePerson(userId: String, personId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await firestoreService.deletePerson(userId: userId, personId: personId)
            persons.removeAll { $0.id == personId }
            isLoading = false
        } catch {
            errorMessage = "인물 삭제에 실패했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Local Operations

    func addPersonLocally(name: String, restrictedIngredients: [String]) {
        let newPerson = Person(
            id: UUID().uuidString,
            name: name,
            restrictedIngredients: restrictedIngredients
        )
        persons.append(newPerson)
    }

    func deletePersonLocally(personId: String) {
        persons.removeAll { $0.id == personId }
    }

    func updatePersonLocally(person: Person) {
        if let index = persons.firstIndex(where: { $0.id == person.id }) {
            persons[index] = person
        }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        persons = Person.sample
    }
}
