import SwiftUI
import Charts

struct MiniDashboardView: View {
    let subjects: [Subject]
    @Environment(\.colorScheme) var colorScheme
    
    private var gradingSystem: GradingSystemPlugin {
        GradingSystemRegistry.active
    }
    
    private var validSubjects: [Subject] {
        subjects.filter { subject in
            let grade = subject.currentGrade
            return grade != NO_GRADE && gradingSystem.validate(grade)
        }
    }
    
    private var generalAverage: Double {
        guard !validSubjects.isEmpty else { return NO_GRADE }
        
        let totalWeightedGrades = validSubjects.reduce(0.0) { total, subject in
            total + (subject.currentGrade * (subject.coefficient > 0 ? subject.coefficient : 1.0))
        }
        let totalCoefficients = validSubjects.reduce(0.0) { total, subject in
            total + (subject.coefficient > 0 ? subject.coefficient : 1.0)
        }
        
        guard totalCoefficients > 0 else { return NO_GRADE }
        let average = totalWeightedGrades / totalCoefficients
        
        return average.isNaN || average.isInfinite ? NO_GRADE : average.rounded(toPlaces: gradingSystem.decimalPlaces)
    }
    
    private var gradeDistribution: [GradeCategory] {
        guard !validSubjects.isEmpty else { return [] }
        
        var distribution: [String: Int] = [:]
        
        for subject in validSubjects {
            let category = getCategoryForGrade(subject.currentGrade)
            distribution[category, default: 0] += 1
        }
        
        let categories = distribution.compactMap { key, value -> GradeCategory? in
            guard value > 0 else { return nil }
            let percentage = Double(value) / Double(validSubjects.count) * 100
            
            return GradeCategory(
                name: key,
                count: value,
                percentage: percentage,
                color: colorForCategory(key)
            )
        }
        
        // Tri par ordre de qualité (excellent d'abord)
        return categories.sorted { category1, category2 in
            let order = ["excellent": 0, "veryGood": 1, "good": 2, "average": 3, "failure": 4]
            return (order[category1.name] ?? 5) < (order[category2.name] ?? 5)
        }
    }
    
    private var donutSegments: [DonutSegment] {
        guard !gradeDistribution.isEmpty else { return [] }
        
        let total = gradeDistribution.reduce(0) { $0 + $1.count }
        var currentAngle: Double = 0
        
        return gradeDistribution.map { category in
            let segmentAngle = (Double(category.count) / Double(total)) * 180
            let segment = DonutSegment(
                startAngle: currentAngle,
                endAngle: currentAngle + segmentAngle,
                color: category.color,
                category: category.name
            )
            currentAngle += segmentAngle
            return segment
        }
    }
    
    private func getCategoryForGrade(_ grade: Double) -> String {
        guard !grade.isNaN && !grade.isInfinite && gradingSystem.validate(grade) else {
            return "failure"
        }
        
        let color = gradingSystem.gradeColor(for: grade)
        
        switch color {
        case GradeColor.excellent: return "excellent"
        case GradeColor.veryGood: return "veryGood"
        case GradeColor.good: return "good"
        case GradeColor.average: return "average"
        default: return "failure"
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "excellent": return GradeColor.excellent
        case "veryGood": return GradeColor.veryGood
        case "good": return GradeColor.good
        case "average": return GradeColor.average
        case "failure": return GradeColor.failure
        default: return GradeColor.noGrade
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Moyenne générale
            VStack(alignment: .leading, spacing: 4) {
                if validSubjects.isEmpty || generalAverage == NO_GRADE {
                    Text("--")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(.secondary)
                } else {
                    Text(formatNumber(generalAverage, places: gradingSystem.decimalPlaces))
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundColor(gradingSystem.gradeColor(for: generalAverage))
                }
                
                Text("Moyenne")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Demi-donut corrigé et agrandi
            SemiDonutChart(segments: donutSegments)
                .rotationEffect(.degrees(180))
                .padding(.top, 55)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
        )
    }
}

// STRUCTURES
struct DonutSegment {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let category: String
}

struct GradeCategory {
    let name: String
    let count: Int
    let percentage: Double
    let color: Color
}

// COMPOSANT CORRIGÉ ET AGRANDI : SemiDonutChart
struct SemiDonutChart: View {
    let segments: [DonutSegment]
    private let outerRadius: CGFloat = 55  // Agrandi de 30 à 45
    private let innerRadius: CGFloat = 35  // Agrandi de 18 à 27
    
    var body: some View {
        ZStack {
            if segments.isEmpty {
                emptyStateView
            } else {
                segmentsView
                separatorLinesView
            }
        }
        .frame(width: 120, height: 60)
        .scaleEffect(x: -1, y: 1)
    }
    
    private var emptyStateView: some View {
        Path { path in
            let center = CGPoint(x: 60, y: 30)  // Ajusté de (40, 20) à (60, 30)
            let averageRadius = (outerRadius + innerRadius) / 2
            
            path.addArc(
                center: center,
                radius: averageRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        .stroke(GradeColor.noGrade.opacity(0.3), lineWidth: outerRadius - innerRadius)
    }
    
    private var segmentsView: some View {
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            segmentPath(for: segment)
                .fill(segment.color)
        }
    }
    
    private func segmentPath(for segment: DonutSegment) -> Path {
        Path { path in
            let center = CGPoint(x: 60, y: 30)  // Ajusté de (40, 20) à (60, 30)
            
            let startRadians = segment.startAngle * Double.pi / 180
            let endRadians = segment.endAngle * Double.pi / 180
            
            // Points de départ
            let outerStartX = center.x + outerRadius * cos(startRadians)
            let outerStartY = center.y + outerRadius * sin(startRadians)
            
            // Commencer le chemin
            path.move(to: CGPoint(x: outerStartX, y: outerStartY))
            
            // Arc externe
            path.addArc(
                center: center,
                radius: outerRadius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
            
            // Point final interne
            let innerEndX = center.x + innerRadius * cos(endRadians)
            let innerEndY = center.y + innerRadius * sin(endRadians)
            path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))
            
            // Arc interne
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: Angle(radians: endRadians),
                endAngle: Angle(radians: startRadians),
                clockwise: true
            )
            
            path.closeSubpath()
        }
    }
    
    private var separatorLinesView: some View {
        ForEach(Array(segments.dropLast().enumerated()), id: \.offset) { index, segment in
            separatorLine(at: segment.endAngle)
        }
    }
    
    private func separatorLine(at angle: Double) -> some View {
        Path { path in
            let center = CGPoint(x: 60, y: 30)  // Ajusté de (40, 20) à (60, 30)
            let angleRadians = angle * Double.pi / 180
            
            let innerX = center.x + innerRadius * cos(angleRadians)
            let innerY = center.y + innerRadius * sin(angleRadians)
            let outerX = center.x + outerRadius * cos(angleRadians)
            let outerY = center.y + outerRadius * sin(angleRadians)
            
            path.move(to: CGPoint(x: innerX, y: innerY))
            path.addLine(to: CGPoint(x: outerX, y: outerY))
        }
        .stroke(Color(.systemBackground), lineWidth: 2)
    }
}
