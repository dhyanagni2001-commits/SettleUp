//
//  Theme.swift
//  SplitWiseClone
//
//  Shared visual vocabulary: category icons/tints, member avatars, and
//  a stable name-derived color so a person looks the same everywhere.
//

import SwiftUI

extension ExpenseCategory {
    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .lodging: "bed.double.fill"
        case .entertainment: "ticket.fill"
        case .utilities: "bolt.fill"
        case .groceries: "cart.fill"
        case .other: "tag.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .lodging: .indigo
        case .entertainment: .pink
        case .utilities: .yellow
        case .groceries: .green
        case .other: .gray
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    // Spotify-inspired palette.
    static let brand = Color(hex: 0x1ED760)
    static let base = Color(hex: 0x121212)
    static let card = Color(hex: 0x1C1C1C)
    static let elevated = Color(hex: 0x2A2A2A)
    static let subtext = Color(hex: 0xB3B3B3)
    static let negative = Color(hex: 0xF15E6C)

    /// Deterministic across launches (unlike `hashValue`). Muted, genre-tile style hues.
    static func stable(for name: String) -> Color {
        let palette: [Color] = [0xE13300, 0x1E3264, 0x8D67AB, 0xE8115B, 0x148A08, 0xBA5D07, 0x477D95, 0xDC148C, 0x27856A, 0x503750].map(Color.init(hex:))
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[seed % palette.count]
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.stable(for: name).gradient))
            .overlay(Circle().stroke(Color.base, lineWidth: 2))
    }
}

struct AvatarStack: View {
    let members: [Member]
    var size: CGFloat = 26
    var limit = 5

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(members.prefix(limit)) { Avatar(name: $0.name, size: size) }
            if members.count > limit {
                Text("+\(members.count - limit)")
                    .font(.caption2.bold())
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.elevated))
            }
        }
    }
}

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(category.tint.gradient))
            .animation(.snappy, value: category)
    }
}

extension View {
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Error", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
