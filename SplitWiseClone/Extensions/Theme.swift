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
        case .food: Color(hex: 0xB0794A)
        case .transport: Color(hex: 0x4F7393)
        case .lodging: Color(hex: 0x6A6890)
        case .entertainment: Color(hex: 0x8E6478)
        case .utilities: Color(hex: 0xA08F4E)
        case .groceries: Color(hex: 0x5A8A63)
        case .other: Color(hex: 0x6B7075)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    // Calm dark palette with a single green accent.
    static let brand = Color(hex: 0x1ED760)
    static let base = Color(hex: 0x121212)
    static let card = Color(hex: 0x1C1C1C)
    static let elevated = Color(hex: 0x2A2A2A)
    static let subtext = Color(hex: 0xB3B3B3)
    static let negative = Color(hex: 0xF15E6C)

    /// Deterministic across launches (unlike `hashValue`). Muted, low-saturation hues
    /// that sit quietly next to the green accent.
    static func stable(for name: String) -> Color {
        let palette: [Color] = [0x3E6B5A, 0x3F5A7A, 0x5B5878, 0x6E5A4A, 0x4A6870, 0x6B6450, 0x4F5D6B, 0x5E6B4E].map(Color.init(hex:))
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
