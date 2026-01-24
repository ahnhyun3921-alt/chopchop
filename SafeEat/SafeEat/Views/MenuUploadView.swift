//
//  MenuUploadView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import PhotosUI

struct MenuUploadView: View {
    @StateObject private var viewModel = MenuUploadViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.safeEatBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 안내 메시지
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.safeEatPrimary)

                            Text("메뉴판 사진을 등록해주세요")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.safeEatTextPrimary)

                            Text("사진에서 자동으로 메뉴를 인식합니다\n(완전 무료 - Apple Vision 사용)")
                                .font(.system(size: 14))
                                .foregroundColor(.safeEatTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)

                        // 식당 검색
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. 식당 선택")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.safeEatTextPrimary)

                            NavigationLink(destination: RestaurantSelectionView(selectedRestaurant: $viewModel.selectedRestaurant)) {
                                HStack {
                                    if let restaurant = viewModel.selectedRestaurant {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(restaurant.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.safeEatTextPrimary)

                                            Text(restaurant.address)
                                                .font(.system(size: 12))
                                                .foregroundColor(.safeEatTextSecondary)
                                                .lineLimit(1)
                                        }
                                    } else {
                                        Text("식당을 선택하세요")
                                            .font(.system(size: 15))
                                            .foregroundColor(.safeEatTextSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.safeEatTextSecondary)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        // 사진 촬영/선택
                        VStack(alignment: .leading, spacing: 12) {
                            Text("2. 메뉴판 사진")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.safeEatTextPrimary)

                            if let image = viewModel.selectedImage {
                                // 선택된 이미지 표시
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 300)
                                        .cornerRadius(12)

                                    Button(action: {
                                        viewModel.selectedImage = nil
                                        viewModel.extractedMenus = []
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .padding(8)
                                }
                            } else {
                                // 사진 선택 버튼
                                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 20))
                                        Text("사진 선택")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(.safeEatPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.safeEatPrimary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // OCR 실행 버튼
                        if viewModel.selectedImage != nil && viewModel.selectedRestaurant != nil && !viewModel.isProcessing {
                            Button(action: {
                                Task {
                                    await viewModel.processImage()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "text.viewfinder")
                                    Text("메뉴 인식하기")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.safeEatPrimary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }

                        // 로딩
                        if viewModel.isProcessing {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .safeEatPrimary))
                                Text("메뉴를 인식하는 중...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.safeEatTextSecondary)
                            }
                            .padding()
                        }

                        // 인식된 메뉴 목록
                        if !viewModel.extractedMenus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("3. 인식된 메뉴 (\(viewModel.extractedMenus.count)개)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.safeEatTextPrimary)

                                Text("내용을 확인하고 수정하세요")
                                    .font(.system(size: 13))
                                    .foregroundColor(.safeEatTextSecondary)

                                ForEach(viewModel.extractedMenus.indices, id: \.self) { index in
                                    MenuEditCard(menu: $viewModel.extractedMenus[index], onDelete: {
                                        viewModel.extractedMenus.remove(at: index)
                                    })
                                }

                                // 저장 버튼
                                Button(action: {
                                    Task {
                                        await viewModel.saveMenus()
                                        if viewModel.saveSuccess {
                                            dismiss()
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("메뉴 저장하기")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // 에러 메시지
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("메뉴 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Menu Edit Card
struct MenuEditCard: View {
    @Binding var menu: Menu
    let onDelete: () -> Void

    @State private var name: String
    @State private var priceString: String
    @State private var ingredientsString: String

    init(menu: Binding<Menu>, onDelete: @escaping () -> Void) {
        self._menu = menu
        self.onDelete = onDelete
        self._name = State(initialValue: menu.wrappedValue.name)
        self._priceString = State(initialValue: "\(menu.wrappedValue.price)")
        self._ingredientsString = State(initialValue: menu.wrappedValue.ingredients.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("메뉴명")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.safeEatTextSecondary)
                    .frame(width: 60, alignment: .leading)

                TextField("메뉴명", text: $name)
                    .font(.system(size: 15))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: name) { newValue in
                        updateMenu()
                    }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("가격")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.safeEatTextSecondary)
                    .frame(width: 60, alignment: .leading)

                TextField("가격", text: $priceString)
                    .font(.system(size: 15))
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: priceString) { newValue in
                        updateMenu()
                    }

                Text("원")
                    .font(.system(size: 14))
                    .foregroundColor(.safeEatTextSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("재료 (쉼표로 구분)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.safeEatTextSecondary)

                TextField("예: 돼지고기, 김치, 두부", text: $ingredientsString)
                    .font(.system(size: 15))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: ingredientsString) { newValue in
                        updateMenu()
                    }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func updateMenu() {
        let price = Int(priceString) ?? 0
        let ingredients = ingredientsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        menu = Menu(
            id: menu.id,
            restaurantId: menu.restaurantId,
            name: name,
            price: price,
            ingredients: ingredients
        )
    }
}

// MARK: - Restaurant Selection View
struct RestaurantSelectionView: View {
    @Binding var selectedRestaurant: Restaurant?
    @StateObject private var viewModel = RestaurantSearchViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 검색바
            SearchBar(text: $searchText, onSearch: {
                Task {
                    await viewModel.searchRestaurants(
                        keyword: searchText,
                        location: locationManager.currentLocation
                    )
                }
            })
            .padding()

            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if viewModel.restaurants.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.safeEatTextSecondary)
                    Text("식당을 검색하세요")
                        .font(.system(size: 14))
                        .foregroundColor(.safeEatTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.restaurants) { restaurant in
                    Button(action: {
                        selectedRestaurant = restaurant
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.safeEatTextPrimary)

                                Text(restaurant.address)
                                    .font(.system(size: 12))
                                    .foregroundColor(.safeEatTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if selectedRestaurant?.id == restaurant.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.safeEatPrimary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("식당 선택")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestLocation()
        }
    }
}

// MARK: - View Model
@MainActor
class MenuUploadViewModel: ObservableObject {
    @Published var selectedRestaurant: Restaurant?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var extractedMenus: [Menu] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false

    private let ocrService = OCRService.shared
    private let firestoreService = FirestoreService.shared

    init() {
        // PhotosPickerItem 변경 감지
        Task {
            for await item in $selectedPhotoItem.values {
                if let item = item {
                    await loadImage(from: item)
                }
            }
        }
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                self.selectedImage = image
            }
        } catch {
            self.errorMessage = "이미지를 불러올 수 없습니다"
        }
    }

    func processImage() async {
        guard let image = selectedImage,
              let restaurant = selectedRestaurant else {
            errorMessage = "식당과 이미지를 선택해주세요"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            // OCR로 텍스트 추출
            let text = try await ocrService.extractText(from: image)

            // 메뉴 파싱
            let menus = ocrService.parseMenus(from: text, restaurantId: restaurant.id)

            await MainActor.run {
                if menus.isEmpty {
                    errorMessage = "메뉴를 인식하지 못했습니다.\n수동으로 추가해주세요."
                } else {
                    extractedMenus = menus
                }
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "OCR 처리 중 오류가 발생했습니다: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    func saveMenus() async {
        guard !extractedMenus.isEmpty else {
            errorMessage = "저장할 메뉴가 없습니다"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
            let userId = "temp_user_id"

            // 각 메뉴를 Firestore에 저장
            for menu in extractedMenus {
                var menuWithContributor = menu
                // contributorId 업데이트는 생성자가 있으니 새로 생성
                let updatedMenu = Menu(
                    id: menu.id,
                    restaurantId: menu.restaurantId,
                    name: menu.name,
                    price: menu.price,
                    description: menu.description,
                    ingredients: menu.ingredients,
                    imageUrl: menu.imageUrl,
                    probabilityTags: menu.probabilityTags,
                    contributorId: userId,
                    createdAt: Date()
                )
                try await firestoreService.addMenu(updatedMenu)
            }

            // 이미지는 즉시 삭제 (저작권 보호)
            await MainActor.run {
                selectedImage = nil
                saveSuccess = true
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "메뉴 저장 중 오류가 발생했습니다: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
}

struct MenuUploadView_Previews: PreviewProvider {
    static var previews: some View {
        MenuUploadView()
    }
}
