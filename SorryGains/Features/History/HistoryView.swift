import SwiftData
import SwiftUI

struct HistoryView: View {
    private enum DisplayMode: String, CaseIterable, Identifiable {
        case list
        case calendar

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .list: "リスト"
            case .calendar: "カレンダー"
            }
        }
    }

    private struct CalendarSlot: Identifiable {
        let id = UUID()
        let date: Date?
    }

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DrinkRecord.timestamp, order: .reverse)
    private var records: [DrinkRecord]
    @Query(sort: \DailyTrainingStatus.date, order: .reverse)
    private var dailyTrainingStatuses: [DailyTrainingStatus]

    @State private var recordBeingEdited: DrinkRecord?
    @State private var recordPendingDeletion: DrinkRecord?
    @State private var displayMode: DisplayMode = .list
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDay: Date?
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirmation = false

    private var calendar: Calendar {
        Calendar.current
    }

    private var daySummaries: [DrinkDaySummary] {
        DrinkAnalytics.makeDaySummaries(records: records, statuses: dailyTrainingStatuses, calendar: calendar)
    }

    private var summaryByDay: [Date: DrinkDaySummary] {
        Dictionary(uniqueKeysWithValues: daySummaries.map { summary in
            (calendar.startOfDay(for: summary.date), summary)
        })
    }

    private var hasAnyHistory: Bool {
        !records.isEmpty || !dailyTrainingStatuses.isEmpty
    }

    private var allRecordIDs: Set<UUID> {
        Set(records.map(\.id))
    }

    private var isAllSelected: Bool {
        !allRecordIDs.isEmpty && allRecordIDs.isSubset(of: selectedIDs)
    }

    private var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter.shortStandaloneWeekdaySymbols
    }

    private var monthSlots: [CalendarSlot] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let monthStart = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1

        var slots = Array(repeating: CalendarSlot(date: nil), count: leadingPadding)

        for offset in dayRange {
            let date = calendar.date(byAdding: .day, value: offset - 1, to: monthStart)
            slots.append(CalendarSlot(date: date))
        }

        while slots.count % 7 != 0 {
            slots.append(CalendarSlot(date: nil))
        }

        return slots
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasAnyHistory {
                    VStack(spacing: Spacing.md) {
                        modePicker
                            .padding(.horizontal, Spacing.md)

                        if displayMode == .list {
                            recordsList
                        } else {
                            calendarView
                        }
                    }
                    .padding(.top, Spacing.xs)
                } else {
                    emptyState
                }
            }
            .navigationTitle(String(localized: "history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if displayMode == .list && hasAnyHistory {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "完了" : "選択") {
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting { selectedIDs.removeAll() }
                            }
                        }
                    }
                }
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isAllSelected ? "全解除" : "全選択") {
                            withAnimation {
                                selectedIDs = isAllSelected ? [] : allRecordIDs
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting && !selectedIDs.isEmpty {
                    bulkDeleteBar
                }
            }
        }
        .onChange(of: displayMode) { _, _ in
            isSelecting = false
            selectedIDs.removeAll()
        }
        .alert("削除の確認", isPresented: $showBulkDeleteConfirmation) {
            Button("削除", role: .destructive) { deleteSelectedRecords() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(selectedIDs.count)件の記録を削除しますか？\nこの操作は取り消せません。")
        }
        .sheet(item: $recordBeingEdited) { record in
            DrinkEntryView(record: record)
        }
        .alert(item: $recordPendingDeletion) { record in
            Alert(
                title: Text("history.delete.confirm.title"),
                message: Text(String(
                    localized: "history.delete.confirm.message",
                    defaultValue: "この記録を削除しますか？"
                )),
                primaryButton: .destructive(Text("history.action.delete")) {
                    deleteRecord(record)
                },
                secondaryButton: .cancel(Text("common.cancel"))
            )
        }
        .onAppear {
            let defaultDay = daySummaries.first?.date ?? calendar.startOfDay(for: .now)
            if selectedDay == nil {
                selectedDay = defaultDay
            }
            displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: defaultDay)) ?? displayedMonth
        }
    }

    private var modePicker: some View {
        Picker("表示形式", selection: $displayMode) {
            ForEach(DisplayMode.allCases) { mode in
                Text(mode.titleKey).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "history.empty.title"),
                systemImage: "tray"
            )
        } description: {
            Text("history.empty.description")
        }
    }

    private var recordsList: some View {
        List {
            ForEach(daySummaries) { summary in
                Section(historySectionTitle(for: summary.date)) {
                    DaySummaryOverviewRow(summary: summary)

                    ForEach(summary.records, id: \.id) { record in
                        selectableRecordRow(record)
                    }
                }
            }

            if !isSelecting {
                Section {
                    AdBannerSlot(placement: .historyBottom)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func selectableRecordRow(_ record: DrinkRecord) -> some View {
        HStack(spacing: Spacing.sm) {
            if isSelecting {
                Image(systemName: selectedIDs.contains(record.id)
                    ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(record.id)
                        ? Color.SG.accent : Color.SG.textSecondary)
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace))
            }

            HistoryRecordRow(record: record)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            withAnimation(.snappy(duration: 0.2)) {
                toggleSelection(record.id)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !isSelecting {
                Button { recordBeingEdited = record } label: {
                    Label("history.action.edit", systemImage: "pencil")
                }
                .tint(Color.SG.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isSelecting {
                Button(role: .destructive) { recordPendingDeletion = record } label: {
                    Label("history.action.delete", systemImage: "trash")
                }
            }
        }
    }

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                monthHeader
                weekdayHeader
                monthGrid
                selectedDaySection

                AdBannerSlot(placement: .historyBottom)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(Color.SG.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(currentMonthLabel)
                .font(.SG.title2)
                .foregroundStyle(Color.SG.textPrimary)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(Color.SG.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7), spacing: Spacing.xs) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7), spacing: Spacing.xs) {
            ForEach(monthSlots) { slot in
                if let date = slot.date {
                    calendarDayButton(for: date)
                } else {
                    Color.clear
                        .frame(height: 78)
                }
            }
        }
    }

    private func calendarDayButton(for date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let summary = summaryByDay[normalizedDate]
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: normalizedDate) } ?? false
        let intensity = min(Double(summary?.totalCount ?? 0) / 5.0, 1.0)

        return Button {
            selectedDay = normalizedDate
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: normalizedDate))")
                    .font(.SG.headline)
                    .foregroundStyle(isSelected ? Color.white : Color.SG.textPrimary)

                if let summary {
                    Image(systemName: summary.didTrain ? "dumbbell.fill" : "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : (summary.didTrain ? Color.SG.accent : Color.SG.textSecondary))

                    Text(summary.totalCount == 0 ? "0杯" : "\(summary.totalCount)杯")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.SG.textSecondary)
                } else {
                    Spacer()
                        .frame(height: 24)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                    .fill(
                        isSelected
                            ? Color.SG.accent
                            : Color.SG.surface.opacity(0.9)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                    .stroke(
                        isSelected
                            ? Color.SG.accent
                            : Color.SG.accent.opacity(summary == nil ? 0.05 : (0.08 + intensity * 0.2)),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        if let selectedDay {
            let summary = summaryByDay[calendar.startOfDay(for: selectedDay)]

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(selectedDayTitle(selectedDay))
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                if let summary {
                    DaySummaryOverviewCard(summary: summary)

                    if summary.records.isEmpty {
                        Text("この日は筋トレ状況のみ記録されています。")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    } else {
                        ForEach(summary.records, id: \.id) { record in
                            HistoryRecordRow(record: record)
                        }
                    }
                } else {
                    SGCard {
                        Text("この日の記録はまだありません。")
                            .font(.SG.body)
                            .foregroundStyle(Color.SG.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func deleteRecord(_ record: DrinkRecord) {
        withAnimation {
            modelContext.delete(record)
            try? modelContext.save()
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func deleteSelectedRecords() {
        let idsToDelete = selectedIDs
        withAnimation {
            for record in records where idsToDelete.contains(record.id) {
                modelContext.delete(record)
            }
            try? modelContext.save()
            selectedIDs.removeAll()
            isSelecting = false
        }
    }

    private func shiftMonth(by offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        selectedDay = selectedDayForCurrentMonth(startingAt: monthStart)
    }

    private func selectedDayForCurrentMonth(startingAt monthStart: Date) -> Date {
        if let summary = daySummaries.first(where: {
            calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month)
        }) {
            return summary.date
        }

        return monthStart
    }

    private func historySectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func selectedDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMdEE")
        return formatter.string(from: date)
    }

    // MARK: - Bulk Delete Bar

    private var bulkDeleteBar: some View {
        HStack {
            Text("\(selectedIDs.count)件選択中")
                .font(.SG.headline)
                .foregroundStyle(Color.SG.textPrimary)

            Spacer()

            Button(role: .destructive) {
                showBulkDeleteConfirmation = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "trash")
                    Text("\(selectedIDs.count)件削除")
                }
                .font(.SG.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }
}

private struct DaySummaryOverviewRow: View {
    let summary: DrinkDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(summary.didTrain ? "筋トレした" : "筋トレしてない", systemImage: summary.didTrain ? "dumbbell.fill" : "moon.zzz.fill")
                    .font(.SG.caption)
                    .foregroundStyle(summary.didTrain ? Color.SG.accent : Color.SG.textSecondary)

                Spacer()

                Text("\(summary.totalCount)杯")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
            }

            if summary.drinkSummaries.isEmpty {
                Text("飲酒記録はありません")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
            } else {
                Text(summary.drinkSummaries.map {
                    String(format: String(localized: "drink.summary.item"), $0.drinkType.localizedName, $0.count)
                }.joined(separator: String(localized: "drink.summary.separator")))
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textPrimary)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

private struct DaySummaryOverviewCard: View {
    let summary: DrinkDaySummary

    var body: some View {
        SGCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Label(summary.didTrain ? "筋トレした日" : "筋トレしてない日", systemImage: summary.didTrain ? "dumbbell.fill" : "moon.zzz.fill")
                        .font(.SG.headline)
                        .foregroundStyle(summary.didTrain ? Color.SG.accent : Color.SG.textSecondary)

                    Spacer()

                    Text("\(summary.totalCount)杯")
                        .font(.SG.caption)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.SG.accent.opacity(0.12))
                        .foregroundStyle(Color.SG.accent)
                        .clipShape(Capsule())
                }

                if summary.drinkSummaries.isEmpty {
                    Text("お酒の記録はありません")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)
                } else {
                    ForEach(summary.drinkSummaries) { drinkSummary in
                        HStack {
                            Label(drinkSummary.drinkType.localizedName, systemImage: drinkSummary.drinkType.symbolName)
                                .font(.SG.body)
                                .foregroundStyle(Color.SG.textPrimary)

                            Spacer()

                            Text("\(drinkSummary.count)杯")
                                .font(.SG.caption)
                                .foregroundStyle(Color.SG.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryRecordRow: View {
    let record: DrinkRecord

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.timestamp)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: record.drinkType.symbolName)
                .font(.title3)
                .foregroundStyle(Color.SG.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.drinkType.localizedName)
                    .font(.SG.headline)
                    .foregroundStyle(Color.SG.textPrimary)

                Text("\(Int(record.volumeML))ml / \(String(format: "%.1f", record.alcoholPercent))%")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
            }

            Spacer()

            Text(timeString)
                .font(.SG.caption)
                .foregroundStyle(Color.SG.textSecondary)
        }
        .padding(.vertical, Spacing.xxs)
    }
}
