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
    @State private var searchText = ""
    @State private var isEditingDefault = false

    // 검색 자동완성 관련
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @State private var showSearchResults = false
    @FocusState private var isSearchFocused: Bool

    // 현재 위치 관련
    @StateObject private var locationHelper = CurrentLocationHelper()

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
                Section {
                    // 검색 입력 필드
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(WanderColors.textTertiary)

                        TextField("주소 또는 장소명 검색", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFocused)
                            .onChange(of: searchText) { _, newValue in
                                searchCompleter.search(query: newValue)
                                showSearchResults = !newValue.isEmpty
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchCompleter.results = []
                                showSearchResults = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(WanderColors.textTertiary)
                            }
                        }
                    }

                    // 검색 중 표시
                    if searchCompleter.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("검색 중...")
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.textTertiary)
                            Spacer()
                        }
                        .padding(.vertical, WanderSpacing.space2)
                    }

                    // 검색 결과 목록
                    if showSearchResults && !searchCompleter.results.isEmpty {
                        ForEach(searchCompleter.results, id: \.self) { completion in
                            Button(action: { selectCompletion(completion) }) {
                                HStack(spacing: WanderSpacing.space3) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(WanderColors.primary)
                                        .font(.system(size: 20))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .font(WanderTypography.body)
                                            .foregroundColor(WanderColors.textPrimary)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(WanderTypography.caption1)
                                                .foregroundColor(WanderColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(WanderColors.textTertiary)
                                        .font(.system(size: 12))
                                }
                                .padding(.vertical, WanderSpacing.space1)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 검색 결과 없음
                    if showSearchResults && searchCompleter.results.isEmpty && !searchCompleter.isSearching && !searchText.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: WanderSpacing.space2) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(WanderColors.textTertiary)
                                Text("검색 결과가 없습니다")
                                    .font(WanderTypography.caption1)
                                    .foregroundColor(WanderColors.textTertiary)
                            }
                            .padding(.vertical, WanderSpacing.space4)
                            Spacer()
                        }
                    }

                    // 선택된 주소 표시
                    if !address.isEmpty {
                        HStack(spacing: WanderSpacing.space2) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(WanderColors.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("선택된 주소")
                                    .font(WanderTypography.caption2)
                                    .foregroundColor(WanderColors.textTertiary)
                                Text(address)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, WanderSpacing.space1)
                    }
                } header: {
                    Text("주소")
                } footer: {
                    Text("주소 또는 장소명을 입력하면 자동완성됩니다")
                        .font(WanderTypography.caption2)
                }

                // 현재 위치 버튼
                Section {
                    Button(action: requestCurrentLocation) {
                        HStack {
                            if locationHelper.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .foregroundColor(WanderColors.primary)
                            }
                            Text(locationHelper.isLoading ? "위치 확인 중..." : "현재 위치 사용")
                                .foregroundColor(locationHelper.isLoading ? WanderColors.textTertiary : WanderColors.primary)
                        }
                    }
                    .disabled(locationHelper.isLoading)

                    if let error = locationHelper.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(WanderColors.warning)
                            Text(error)
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.warning)
                        }
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
                        .onTapGesture {
                            // 지도 탭 시 검색 포커스 해제
                            isSearchFocused = false
                        }
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
            .onReceive(locationHelper.$location) { location in
                if let location = location {
                    applyLocation(location)
                }
            }
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isSearchFocused = false
        showSearchResults = false
        searchText = ""
        searchCompleter.isSearching = true

        // MKLocalSearchCompletion을 실제 좌표로 변환
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        search.start { response, error in
            searchCompleter.isSearching = false

            if let mapItem = response?.mapItems.first {
                let coordinate = mapItem.placemark.coordinate
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                address = [completion.title, completion.subtitle]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                logger.info("📍 [UserPlaces] 주소 선택: \(address)")
            }
        }
    }

    private func requestCurrentLocation() {
        locationHelper.requestLocation()
    }

    private func applyLocation(_ location: CLLocation) {
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
                if let subThoroughfare = placemark.subThoroughfare {
                    addressComponents.append(subThoroughfare)
                }
                address = addressComponents.joined(separator: " ")
                logger.info("📍 [UserPlaces] 현재 위치: \(address)")
            }
        }
    }
}

// MARK: - Address Search Completer
@MainActor
class AddressSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var searchTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // 한국 지역으로 검색 범위 설정
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5),
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )
    }

    func search(query: String) {
        // 이전 검색 취소
        searchTask?.cancel()

        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounce: 300ms 후 검색
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            completer.queryFragment = query
        }
    }
}

extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = Array(completer.results.prefix(8))
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            logger.warning("📍 [AddressSearch] 검색 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - Current Location Helper
@MainActor
class CurrentLocationHelper: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        isLoading = true
        errorMessage = nil
        location = nil

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "위치 권한이 필요합니다. 설정에서 허용해주세요."
        @unknown default:
            isLoading = false
            errorMessage = "위치를 가져올 수 없습니다."
        }
    }
}

extension CurrentLocationHelper: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if self.isLoading {
                    manager.requestLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.isLoading = false
            if let location = locations.first {
                self.location = location
                logger.info("📍 [Location] 현재 위치 획득: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.errorMessage = "위치 권한이 거부되었습니다."
                case .locationUnknown:
                    self.errorMessage = "현재 위치를 확인할 수 없습니다."
                default:
                    self.errorMessage = "위치를 가져오는 데 실패했습니다."
                }
            } else {
                self.errorMessage = "위치를 가져오는 데 실패했습니다."
            }
            logger.warning("📍 [Location] 위치 오류: \(error.localizedDescription)")
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
