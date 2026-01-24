//
//  PersonManagementView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct PersonManagementView: View {
    @StateObject private var viewModel = PersonManagementViewModel()
    @State private var showAddPersonSheet = false
    @State private var editingPerson: Person?

    var body: some View {
        NavigationView {
            ZStack {
                Color.safeEatBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.persons.isEmpty {
                        EmptyPersonsView(onAddPerson: { showAddPersonSheet = true })
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.persons) { person in
                                    PersonCard(
                                        person: person,
                                        onEdit: {
                                            editingPerson = person
                                        },
                                        onDelete: {
                                            // TODO: Firebase userId 가져오기
                                            viewModel.deletePersonLocally(personId: person.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }
                }
            }
            .navigationTitle("인물 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddPersonSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.safeEatPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddPersonSheet) {
                AddPersonView { name, allergens in
                    viewModel.addPersonLocally(name: name, restrictedIngredients: allergens)
                }
            }
            .sheet(item: $editingPerson) { person in
                EditPersonView(person: person) { updatedPerson in
                    viewModel.updatePersonLocally(person: updatedPerson)
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyPersonsView: View {
    let onAddPerson: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundColor(.safeEatTextSecondary.opacity(0.5))

            Text("등록된 인물이 없습니다")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.safeEatTextPrimary)

            Text("가족 구성원을 추가하고\n각자의 알레르기 정보를 관리하세요")
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextSecondary)
                .multilineTextAlignment(.center)

            Button(action: onAddPerson) {
                Text("첫 번째 인물 추가하기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.safeEatPrimary)
                    .cornerRadius(24)
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Person Card

struct PersonCard: View {
    let person: Person
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 아이콘
                Circle()
                    .fill(Color.safeEatPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(person.name.prefix(1))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.safeEatPrimary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.safeEatTextPrimary)

                    Text("\(person.restrictedIngredients.count)개 제한 식품")
                        .font(.system(size: 14))
                        .foregroundColor(.safeEatTextSecondary)
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label("수정", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.safeEatTextSecondary)
                        .padding(8)
                }
            }

            if !person.restrictedIngredients.isEmpty {
                Divider()
                    .background(Color(hex: "#EEEEEE"))

                // 제한 식품 태그
                FlowLayout(spacing: 8) {
                    ForEach(person.restrictedIngredients, id: \.self) { ingredient in
                        Text(ingredient)
                            .font(.system(size: 13))
                            .foregroundColor(.safeEatPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.safeEatPrimary.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert("인물 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: onDelete)
        } message: {
            Text("\(person.name)님을 삭제하시겠습니까?")
        }
    }
}

// MARK: - Add Person View

struct AddPersonView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, [String]) -> Void

    @State private var name = ""
    @State private var selectedAllergens: Set<String> = []

    let availableAllergens = [
        "우유", "쇠고기", "돼지고기", "닭고기",
        "새우", "갑각류", "조개", "게",
        "달걀", "땅콩", "밀", "대두",
        "고등어", "복숭아", "토마토",
        "아황산류", "호두", "잣", "메밀"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("이름", text: $name)
                        .font(.system(size: 16))
                } header: {
                    Text("인물 정보")
                }

                Section {
                    ForEach(availableAllergens, id: \.self) { allergen in
                        AllergenToggleRow(
                            allergen: allergen,
                            isSelected: selectedAllergens.contains(allergen),
                            onToggle: {
                                if selectedAllergens.contains(allergen) {
                                    selectedAllergens.remove(allergen)
                                } else {
                                    selectedAllergens.insert(allergen)
                                }
                            }
                        )
                    }
                } header: {
                    Text("제한 식품 (알레르기)")
                } footer: {
                    Text("해당 인물이 섭취할 수 없는 재료를 선택하세요")
                }
            }
            .navigationTitle("인물 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("추가") {
                        onSave(name, Array(selectedAllergens))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? .gray : .safeEatPrimary)
                }
            }
        }
    }
}

// MARK: - Edit Person View

struct EditPersonView: View {
    @Environment(\.dismiss) var dismiss
    let person: Person
    let onSave: (Person) -> Void

    @State private var name: String
    @State private var selectedAllergens: Set<String>

    let availableAllergens = [
        "우유", "쇠고기", "돼지고기", "닭고기",
        "새우", "갑각류", "조개", "게",
        "달걀", "땅콩", "밀", "대두",
        "고등어", "복숭아", "토마토",
        "아황산류", "호두", "잣", "메밀"
    ]

    init(person: Person, onSave: @escaping (Person) -> Void) {
        self.person = person
        self.onSave = onSave
        _name = State(initialValue: person.name)
        _selectedAllergens = State(initialValue: Set(person.restrictedIngredients))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("이름", text: $name)
                        .font(.system(size: 16))
                } header: {
                    Text("인물 정보")
                }

                Section {
                    ForEach(availableAllergens, id: \.self) { allergen in
                        AllergenToggleRow(
                            allergen: allergen,
                            isSelected: selectedAllergens.contains(allergen),
                            onToggle: {
                                if selectedAllergens.contains(allergen) {
                                    selectedAllergens.remove(allergen)
                                } else {
                                    selectedAllergens.insert(allergen)
                                }
                            }
                        )
                    }
                } header: {
                    Text("제한 식품 (알레르기)")
                } footer: {
                    Text("해당 인물이 섭취할 수 없는 재료를 선택하세요")
                }
            }
            .navigationTitle("인물 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        let updatedPerson = Person(
                            id: person.id,
                            name: name,
                            restrictedIngredients: Array(selectedAllergens)
                        )
                        onSave(updatedPerson)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? .gray : .safeEatPrimary)
                }
            }
        }
    }
}

// MARK: - Allergen Toggle Row

struct AllergenToggleRow: View {
    let allergen: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(allergen)
                    .font(.system(size: 15))
                    .foregroundColor(.safeEatTextPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.safeEatPrimary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct PersonManagementView_Previews: PreviewProvider {
    static var previews: some View {
        PersonManagementView()
    }
}
