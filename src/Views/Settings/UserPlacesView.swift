import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "UserPlacesView")

/// 사용자 장소 관리 화면
struct UserPlacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserPlace.order) private var places: [UserPlace]

    @State private var showAddPlace = false
    @State private var placeToEdit: UserPlace?
    @State private var showDeleteConfirmation = false
    @State private var placeToDelete: UserPlace?

    var body: some View {
        List {
            // Default Places Section
            Section {
                ForEach(defaultPlaces) { place in
                    UserPlaceRow(
                        place: place,
                        onEdit: { placeToEdit = place }
                    )
                }
            } header: {
                Text("기본 장소")
            } footer: {
                Text("기본 장소는 주소만 설정할 수 있습니다.")
            }

            // User Places Section
            Section {
                ForEach(userPlaces) { place in
                    UserPlaceRow(
                        place: place,
                        onEdit: { placeToEdit = place }
                    )
                    .contextMenu {
                        Button {
                            placeToEdit = place
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            placeToDelete = place
                            showDeleteConfirmation = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveUserPlaces)

                // Add Button
                Button(action: { showAddPlace = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(WanderColors.primary)
                        Text("장소 추가")
                            .foregroundColor(WanderColors.primary)
                    }
                }
                .disabled(userPlaces.count >= 5)
            } header: {
                HStack {
                    Text("사용자 장소")
                    Spacer()
                    Text("\(userPlaces.count)/5")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                }
            } footer: {
                if userPlaces.count >= 5 {
                    Text("사용자 장소는 최대 5개까지 추가할 수 있습니다.")
                }
            }

            // Info Section
            Section {
                Text("등록한 장소는 기록 분석 시 자동으로 인식됩니다. 반경 100m 이내의 사진은 해당 장소로 표시됩니다.")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }
        }
        .navigationTitle("장소 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .onAppear {
            initializePlacesIfNeeded()
        }
        .sheet(isPresented: $showAddPlace) {
            UserPlaceEditView(mode: .add) { name, icon, latitude, longitude, address in
                addPlace(name: name, icon: icon, latitude: latitude, longitude: longitude, address: address)
            }
        }
        .sheet(item: $placeToEdit) { place in
            UserPlaceEditView(mode: .edit(place)) { name, icon, latitude, longitude, address in
                updatePlace(place, name: name, icon: icon, latitude: latitude, longitude: longitude, address: address)
            }
        }
        .confirmationDialog(
            "이 장소를 삭제하시겠습니까?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let place = placeToDelete {
                    deletePlace(place)
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Computed Properties
    private var defaultPlaces: [UserPlace] {
        places.filter { $0.isDefault }.sorted { $0.order < $1.order }
    }

    private var userPlaces: [UserPlace] {
        places.filter { !$0.isDefault }.sorted { $0.order < $1.order }
    }

    // MARK: - Actions
    private func initializePlacesIfNeeded() {
        if places.isEmpty {
            logger.info("📍 [UserPlaces] 기본 장소 생성")
            for place in UserPlace.createDefaultPlaces() {
                modelContext.insert(place)
            }
            try? modelContext.save()
        }
    }

    private func addPlace(name: String, icon: String, latitude: Double, longitude: Double, address: String) {
        let maxOrder = (userPlaces.map { $0.order }.max() ?? 99) + 1
        let place = UserPlace(
            name: name,
            icon: icon,
            latitude: latitude,
            longitude: longitude,
            address: address,
            isDefault: false,
            order: maxOrder
        )
        modelContext.insert(place)
        try? modelContext.save()
        logger.info("📍 [UserPlaces] 장소 추가: \(name)")
    }

    private func updatePlace(_ place: UserPlace, name: String, icon: String, latitude: Double, longitude: Double, address: String) {
        if !place.isDefault {
            place.name = name
            place.icon = icon
        }
        place.latitude = latitude
        place.longitude = longitude
        place.address = address
        try? modelContext.save()
        logger.info("📍 [UserPlaces] 장소 수정: \(name)")
    }

    private func deletePlace(_ place: UserPlace) {
        modelContext.delete(place)
        try? modelContext.save()
        placeToDelete = nil
        logger.info("📍 [UserPlaces] 장소 삭제: \(place.name)")
    }

    private func moveUserPlaces(from source: IndexSet, to destination: Int) {
        var sorted = userPlaces
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, place) in sorted.enumerated() {
            place.order = 100 + index  // 사용자 장소는 100부터 시작
        }
        try? modelContext.save()
    }
}

// MARK: - Place Row
struct UserPlaceRow: View {
    let place: UserPlace
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: WanderSpacing.space3) {
                // Icon
                ZStack {
                    Circle()
                        .fill(WanderColors.primaryPale)
                        .frame(width: 40, height: 40)

                    Text(place.icon)
                        .font(.system(size: 20))
                }

                // Name & Address
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(place.name)
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textPrimary)

                        if place.isDefault {
                            Text("기본")
                                .font(WanderTypography.caption2)
                                .foregroundColor(WanderColors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WanderColors.border)
                                .cornerRadius(4)
                        }
                    }

                    if place.address.isEmpty {
                        Text("주소 미설정")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textTertiary)
                    } else {
                        Text(place.address)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(.vertical, WanderSpacing.space1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Edit View
enum UserPlaceEditMode: Identifiable {
    case add
    case edit(UserPlace)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let place): return place.id.uuidString
        }
    }
}

struct UserPlaceEditView: View {
    let mode: UserPlaceEditMode
    let onSave: (String, String, Double, Double, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "📍"
    @State private var address: String = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),  // 서울 기본
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isEditingDefault = false

    init(mode: UserPlaceEditMode, onSave: @escaping (String, String, Double, Double, String) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let place) = mode {
            _name = State(initialValue: place.name)
            _selectedIcon = State(initialValue: place.icon)
            _address = State(initialValue: place.address)
            _latitude = State(initialValue: place.latitude)
            _longitude = State(initialValue: place.longitude)
            _isEditingDefault = State(initialValue: place.isDefault)
            if place.latitude != 0 && place.longitude != 0 {
                _region = State(initialValue: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name & Icon (사용자 장소만)
                if !isEditingDefault {
                    Section("이름") {
                        TextField("장소 이름", text: $name)
                            .textInputAutocapitalization(.never)
                    }

                    Section("아이콘") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: WanderSpacing.space3) {
                            ForEach(UserPlace.iconPresets, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Text(icon)
                                        .font(.system(size: 24))
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? WanderColors.primaryPale : Color.clear)
                                        .cornerRadius(WanderSpacing.radiusMedium)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Address Search
                Section("주소") {
                    TextField("주소 검색", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            searchAddress()
                        }

                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults, id: \.self) { item in
                            Button(action: { selectSearchResult(item) }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "")
                                        .font(WanderTypography.body)
                                        .foregroundColor(WanderColors.textPrimary)
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(WanderTypography.caption1)
                                            .foregroundColor(WanderColors.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !address.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(WanderColors.success)
                            Text(address)
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.textSecondary)
                        }
                    }

                    Button("현재 위치 사용") {
                        useCurrentLocation()
                    }
                }

                // Map Preview
                if latitude != 0 && longitude != 0 {
                    Section("지도 미리보기") {
                        Map(coordinateRegion: $region, annotationItems: [UserPlaceAnnotation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]) { annotation in
                            MapMarker(coordinate: annotation.coordinate, tint: WanderColors.primary)
                        }
                        .frame(height: 200)
                        .cornerRadius(WanderSpacing.radiusMedium)
                    }
                }
            }
            .navigationTitle(isEditMode ? (isEditingDefault ? "\(name) 설정" : "장소 편집") : "장소 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(name, selectedIcon, latitude, longitude, address)
                        dismiss()
                    }
                    .disabled(isEditingDefault ? address.isEmpty : name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func searchAddress() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        searchResults = []

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response = response {
                searchResults = Array(response.mapItems.prefix(5))
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        address = item.placemark.title ?? item.name ?? ""
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        searchResults = []
        searchText = ""
    }

    private func useCurrentLocation() {
        // 간단한 위치 요청 (실제로는 LocationManager 사용 권장)
        let manager = CLLocationManager()
        if let location = manager.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )

            // Reverse geocoding
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    var addressComponents: [String] = []
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let subLocality = placemark.subLocality {
                        addressComponents.append(subLocality)
                    }
                    if let thoroughfare = placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    address = addressComponents.joined(separator: " ")
                }
            }
        }
    }
}

// MARK: - Place Annotation
struct UserPlaceAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    NavigationStack {
        UserPlacesView()
    }
    .modelContainer(for: UserPlace.self, inMemory: true)
}
