import ActivityKit
import WidgetKit
import SwiftUI



// MARK: - COLORS EXTENSION
extension Color {
    static var laAccent: Color {
        Color(red: 0.0, green: 0.48, blue: 1.0) // Bleu iOS premium
    }
    
    static var laSuccess: Color {
        Color(red: 0.2, green: 0.78, blue: 0.35) // Vert iOS
    }
    
    static var laWarning: Color {
        Color(red: 1.0, green: 0.58, blue: 0.0) // Orange iOS
    }
    
    static var laBackground: Color {
        Color(.systemBackground)
    }
    
    static var laSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
}

// MARK: - REVISION LIVE ACTIVITY (EXISTANTE)
struct RevisionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RevisionAttributes.self) { context in
            RevisionLockScreenView(context: context)
                .containerBackground(.background, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                // LEADING REGION - Réduction des paddings
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ZStack {
                                Image("iconG")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 22, height: 22)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(context.attributes.deckName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(context.attributes.subjectName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Status badge plus compact
                        HStack(spacing: 4) {
                            Circle()
                                .fill(context.state.isActive ? Color.green : Color.gray)
                                .frame(width: 3, height: 3)
                            
                            Text(context.state.isActive ? "Active" : "Terminée")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                }
                
                // TRAILING REGION - Ajustement des tailles
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        // Compteur principal plus compact
                        HStack(spacing: 8) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Progression")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(context.state.cardsCompleted) / \(context.state.totalCards)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .contentTransition(.numericText())
                            }
                            
                            // Progress circle plus petit
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                                
                                Circle()
                                    .trim(from: 0, to: context.state.progress)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                    .frame(width: 24, height: 24)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.8), value: context.state.progress)
                                
                                Text("\(Int(context.state.progress * 100))")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                }
                
                // BOTTOM REGION - Barre de progression visible
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        // Titre plus petit
                        Text("Révision en cours")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Labels et barre
                        VStack(spacing: 4) {
                            HStack {
                                Spacer()
                                Text("\(context.state.cardsRemaining) restantes")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            // BARRE DE PROGRESSION CORRIGÉE
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 10)
                                    
                                    if context.state.progress > 0 {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.blue)
                                            .frame(width: geometry.size.width * context.state.progress, height: 10)
                                            .animation(.easeInOut(duration: 0.8), value: context.state.progress)
                                    }
                                }
                            }
                            .frame(height: 10)
                            .frame(maxWidth: 300)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                
            } compactLeading: {
                HStack(spacing: 4) {
                    Image("iconG")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } compactTrailing: {
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.blue))
                        Text("\(context.state.cardsCompleted)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .minimumScaleFactor(1)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                    }
                    .frame(height: 24)
                    .padding(.trailing, 0)
                }
                .frame(maxWidth: .infinity)
            } minimal: {
                ZStack {
                    Image("iconG")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 14, height: 14)
                }
            }
            .contentMargins(.horizontal, 0, for: .expanded)
        }
    }
}



// MARK: - LOCK SCREEN VIEW PREMIUM (REVISION)
@MainActor
struct RevisionLockScreenView: View {
    let context: ActivityViewContext<RevisionAttributes>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec gradient
            headerView
            
            // Content principal
            mainContentView
            
            // Footer avec progression
            progressFooterView
        }
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Icône avec background coloré
            ZStack {
                Image("iconG")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.deckName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(context.attributes.subjectName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status badge
            statusBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(context.state.isActive ? Color.blue : Color.green)
                .frame(width: 6, height: 6)
            
            Text(context.state.isActive ? "En cours" : "Terminée")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(context.state.isActive ? .blue : .green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(context.state.isActive ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        )
    }
    
    private var mainContentView: some View {
        HStack(spacing: 20) {
            // Compteur principal avec design circulaire
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(
                        LinearGradient(
                            colors: [.laAccent, .laAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: context.state.progress)
                
                VStack(spacing: 0) {
                    Text("\(context.state.cardsCompleted)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("/ \(context.state.totalCards)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                // Temps avec icône
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(formatDuration(context.state.sessionDuration))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private var progressFooterView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progression")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.laAccent)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.laAccent, .laAccent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * context.state.progress, height: 6)
                        .animation(.easeInOut(duration: 0.8), value: context.state.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                .laSecondaryBackground,
                .laBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
}
