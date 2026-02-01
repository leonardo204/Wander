import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "CategoryManagementView")

/// 카테고리 관리 화면
struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordCategory.order) private var categories: [RecordCategory]

    @State private var showAddCategory = false
    @State private var categoryToEdit: RecordCategory?
    @State private var showDeleteConfirmation = false
    @State private var categoryToDelete: RecordCategory?

    var body: some View {
        List {
            // Default Categories Section
            Section {
                ForEach(defaultCategories) { category in
                    CategoryRow(
                        category: category,
                        onToggleVisibility: { toggleVisibility(category) },
                        onEdit: nil  // 기본 카테고리는 편집 불가
                    )
                }
            } header: {
                Text("기본 카테고리")
            } footer: {
                Text("기본 카테고리는 숨기기만 가능합니다.")
            }

            // User Categories Section
            Section {
                ForEach(userCategories) { category in
                    CategoryRow(
                        category: category,
                        onToggleVisibility: { toggleVisibility(category) },
                        onEdit: { categoryToEdit = category }
                    )
                    .contextMenu {
                        Button {
                            categoryToEdit = category
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            categoryToDelete = category
                            showDeleteConfirmation = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: moveUserCategories)

                // Add Button
                Button(action: { showAddCategory = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(WanderColors.primary)
                        Text("카테고리 추가")
                            .foregroundColor(WanderColors.primary)
                    }
                }
                .disabled(userCategories.count >= 5)
            } header: {
                HStack {
                    Text("사용자 카테고리")
                    Spacer()
                    Text("\(userCategories.count)/5")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                }
            } footer: {
                if userCategories.count >= 5 {
                    Text("사용자 카테고리는 최대 5개까지 추가할 수 있습니다.")
                }
            }
        }
        .navigationTitle("카테고리 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .onAppear {
            initializeCategoriesIfNeeded()
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryEditView(mode: .add) { name, icon, colorHex in
                addCategory(name: name, icon: icon, colorHex: colorHex)
            }
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditView(mode: .edit(category)) { name, icon, colorHex in
                updateCategory(category, name: name, icon: icon, colorHex: colorHex)
            }
        }
        .confirmationDialog(
            "이 카테고리를 삭제하시겠습니까?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let category = categoryToDelete {
                    deleteCategory(category)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 카테고리를 사용하는 기록은 '기타'로 변경됩니다.")
        }
    }

    // MARK: - Computed Properties
    private var defaultCategories: [RecordCategory] {
        categories.filter { $0.isDefault }.sorted { $0.order < $1.order }
    }

    private var userCategories: [RecordCategory] {
        categories.filter { !$0.isDefault }.sorted { $0.order < $1.order }
    }

    // MARK: - Actions
    private func initializeCategoriesIfNeeded() {
        if categories.isEmpty {
            logger.info("📂 [CategoryManagement] 기본 카테고리 생성")
            for category in RecordCategory.createDefaultCategories() {
                modelContext.insert(category)
            }
            try? modelContext.save()
        }
    }

    private func toggleVisibility(_ category: RecordCategory) {
        category.isHidden.toggle()
        try? modelContext.save()
        logger.info("📂 [CategoryManagement] 카테고리 표시 상태 변경: \(category.name) → \(category.isHidden ? "숨김" : "표시")")
    }

    private func addCategory(name: String, icon: String, colorHex: String) {
        let maxOrder = (userCategories.map { $0.order }.max() ?? 99) + 1
        let category = RecordCategory(
            name: name,
            icon: icon,
            colorHex: colorHex,
            isDefault: false,
            order: maxOrder
        )
        modelContext.insert(category)
        try? modelContext.save()
        logger.info("📂 [CategoryManagement] 카테고리 추가: \(name)")
    }

    private func updateCategory(_ category: RecordCategory, name: String, icon: String, colorHex: String) {
        category.name = name
        category.icon = icon
        category.colorHex = colorHex
        try? modelContext.save()
        logger.info("📂 [CategoryManagement] 카테고리 수정: \(name)")
    }

    private func deleteCategory(_ category: RecordCategory) {
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
        logger.info("📂 [CategoryManagement] 카테고리 삭제: \(category.name)")
    }

    private func moveUserCategories(from source: IndexSet, to destination: Int) {
        var sorted = userCategories
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, category) in sorted.enumerated() {
            category.order = 100 + index  // 사용자 카테고리는 100부터 시작
        }
        try? modelContext.save()
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let category: RecordCategory
    let onToggleVisibility: () -> Void
    let onEdit: (() -> Void)?

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            // Icon & Color
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Text(category.icon)
                    .font(.system(size: 20))
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(WanderTypography.body)
                    .foregroundColor(category.isHidden ? WanderColors.textTertiary : WanderColors.textPrimary)

                if category.isDefault {
                    Text("기본")
                        .font(WanderTypography.caption2)
                        .foregroundColor(WanderColors.textTertiary)
                }
            }

            Spacer()

            // Visibility Toggle
            Button(action: onToggleVisibility) {
                Image(systemName: category.isHidden ? "eye.slash" : "eye")
                    .foregroundColor(category.isHidden ? WanderColors.textTertiary : WanderColors.primary)
            }
            .buttonStyle(.plain)

            // Edit Button (사용자 카테고리만)
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(WanderColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, WanderSpacing.space1)
        .opacity(category.isHidden ? 0.6 : 1.0)
    }
}

// MARK: - Category Edit View
enum CategoryEditMode: Identifiable {
    case add
    case edit(RecordCategory)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let category): return category.id.uuidString
        }
    }
}

struct CategoryEditView: View {
    let mode: CategoryEditMode
    let onSave: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "🎉"
    @State private var selectedColor: String = "#87CEEB"

    init(mode: CategoryEditMode, onSave: @escaping (String, String, String) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let category) = mode {
            _name = State(initialValue: category.name)
            _selectedIcon = State(initialValue: category.icon)
            _selectedColor = State(initialValue: category.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: WanderSpacing.space3) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor).opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Text(selectedIcon)
                                    .font(.system(size: 32))
                            }

                            Text(name.isEmpty ? "카테고리 이름" : name)
                                .font(WanderTypography.headline)
                                .foregroundColor(name.isEmpty ? WanderColors.textTertiary : WanderColors.textPrimary)
                        }
                        .padding(.vertical, WanderSpacing.space4)
                        Spacer()
                    }
                }

                // Name
                Section("이름") {
                    TextField("카테고리 이름", text: $name)
                        .textInputAutocapitalization(.never)
                }

                // Icon Selection
                Section("아이콘") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: WanderSpacing.space3) {
                        ForEach(RecordCategory.iconPresets, id: \.self) { icon in
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

                // Color Selection
                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: WanderSpacing.space3) {
                        ForEach(RecordCategory.colorPresets, id: \.self) { colorHex in
                            Button(action: { selectedColor = colorHex }) {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == colorHex ? WanderColors.textPrimary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(isEditMode ? "카테고리 편집" : "카테고리 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(name, selectedIcon, selectedColor)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
    .modelContainer(for: RecordCategory.self, inMemory: true)
}
