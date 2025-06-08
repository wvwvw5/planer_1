import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var selectedPeriod: TimePeriod = .day
    
    enum TimePeriod: String, CaseIterable {
        case day = "day"
        case month = "month"
        case year = "year"
        
        var localized: String {
            switch self {
            case .day: return NSLocalizedString("period_day", comment: "")
            case .month: return NSLocalizedString("period_month", comment: "")
            case .year: return NSLocalizedString("period_year", comment: "")
            }
        }
    }
    
    var currentCount: Int {
        viewModel.activeTasks.count
    }
    var archiveCount: Int {
        viewModel.completedTasks.count
    }
    var total: Int {
        currentCount + archiveCount
    }
    
    var currentPercentage: Double {
        total > 0 ? Double(currentCount) / Double(total) * 100 : 0
    }
    var archivePercentage: Double {
        total > 0 ? Double(archiveCount) / Double(total) * 100 : 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Picker("period".localized, selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.localized).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if total > 0 {
                    PieChartView(current: currentCount, archive: archiveCount)
                        .frame(width: 220, height: 220)
                    HStack(spacing: 24) {
                        HStack {
                            Circle().fill(Color.blue).frame(width: 16, height: 16)
                            Text("current_tasks".localized + ": \(currentCount) (\(String(format: "%.1f", currentPercentage))%)")
                        }
                        HStack {
                            Circle().fill(Color.green).frame(width: 16, height: 16)
                            Text("archive_tasks".localized + ": \(archiveCount) (\(String(format: "%.1f", archivePercentage))%)")
                        }
                    }
                } else {
                    Text("no_tasks_for_analytics".localized)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("analytics_title".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PieChartView: View {
    var current: Int
    var archive: Int
    
    var body: some View {
        GeometryReader { geo in
            let total = Double(current + archive)
            let currentAngle = total > 0 ? Double(current) / total * 360 : 0
            ZStack {
                // Архив
                PieSlice(startAngle: .degrees(currentAngle), endAngle: .degrees(360))
                    .fill(Color.green.opacity(0.8))
                // Текущие
                PieSlice(startAngle: .degrees(0), endAngle: .degrees(currentAngle))
                    .fill(Color.blue.opacity(0.8))
            }
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        path.closeSubpath()
        return path
    }
} 