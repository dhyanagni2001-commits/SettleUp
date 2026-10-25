//
//  SiriHelpView.swift
//  SplitWiseClone
//
//  A short list of things to say to Siri. SettleUp has no microphone of its
//  own: Siri listens and hands the request to the app's App Intents.
//

import SwiftUI

struct SiriHelpView: View {
    private let examples: [(symbol: String, title: String, phrases: [String])] = [
        ("plus.circle.fill", "Add an expense", [
            "Add an expense to Lisbon Trip in SettleUp",
            "Add a SettleUp expense",
        ]),
        ("person.crop.circle.badge.checkmark", "Check your balance", [
            "Check my balance in SettleUp",
            "What do I owe in SettleUp",
        ]),
        ("arrow.left.arrow.right", "Settlement plan", [
            "Who owes who in Lisbon Trip in SettleUp",
        ]),
        ("rectangle.stack.fill", "Open a group", [
            "Open Lisbon Trip in SettleUp",
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(example.title, systemImage: example.symbol)
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(example.phrases, id: \.self) { phrase in
                            Text("“Hey Siri, \(phrase.prefix(1).lowercased() + phrase.dropFirst())”")
                                .font(.subheadline)
                                .foregroundStyle(Color.subtext)
                        }
                    }
                    .glassCard()
                    .staggeredAppear(index)
                }

                Text("Siri asks for anything you leave out, like the amount or who paid. If a name could match more than one person, Siri asks which one you meant.")
                    .font(.footnote)
                    .foregroundStyle(Color.subtext)
                    .padding(.horizontal, 4)
                    .staggeredAppear(examples.count)

                // Not ShortcutsLink: it labels itself with the bundle name ("SplitWiseClone").
                if let shortcuts = URL(string: "shortcuts://") {
                    Link(destination: shortcuts) {
                        Label("Open Shortcuts", systemImage: "square.stack.3d.up.fill")
                    }
                    .buttonStyle(BrandButtonStyle())
                    .padding(.top, 4)
                    .staggeredAppear(examples.count + 1)
                }
            }
            .padding(16)
        }
        .background { AppBackground() }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
