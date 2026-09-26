# SettleUp — Native iOS Expense Splitting App

A native iOS expense-splitting app built with **SwiftUI**, **MVVM + Combine**,
**Core Data + CloudKit sync**, and an on-device **CoreML** classifier for
automatic expense categorization. The core algorithmic piece is a
**debt-simplification (min-transaction graph reduction)** engine that
collapses a group's tangled IOUs down to the smallest set of payments needed
to settle up.

## Why this exists

Splitting expenses in a group (a trip, a shared apartment, a dinner) quickly
produces a web of who-owes-whom. Rather than showing every individual debt,
this app nets everyone's balance and computes the minimal set of payments
that zeroes the group out — the same problem LeetCode calls "Optimal Account
Balancing."

## Architecture

```
SplitWiseClone/
├── App/                  App entry point, environment wiring
├── Models/                Plain Swift domain types (Group, Member, Expense, Settlement)
├── ViewModels/            ObservableObject classes — Combine-driven state
├── Views/                 SwiftUI views
├── Persistence/           Core Data + CloudKit stack
├── ML/                    On-device CoreML expense categorizer
├── Algorithms/            DebtSimplifier — the min-transaction reduction engine
└── Extensions/            Small Swift extensions

SplitWiseCloneTests/       XCTest unit tests (algorithm, categorizer)
SplitWiseCloneUITests/     UI test target (scaffolded, empty for now)
```

**Pattern:** MVVM. Views are declarative SwiftUI and hold no business logic;
`ObservableObject` ViewModels own state and expose it via `@Published`
properties; Combine pipelines react to Core Data's remote-change
notifications so the UI updates automatically when CloudKit sync brings in
changes from another device.

Core Data entities are prefixed `CD` (`CDGroup`, `CDMember`, `CDExpense`,
`CDExpenseSplit`, `CDSettlement`) to avoid colliding with the plain Swift
domain structs of the same name in `Models/DomainModels.swift`.

## Core Data + CloudKit

Persistence uses `NSPersistentCloudKitContainer`. The local SQLite store is
always the source of truth — every read/write hits it first — so the app is
fully usable offline. CloudKit sync catches up in the background whenever
connectivity returns. The `.xcdatamodeld` is checked in at
`SplitWiseClone/Persistence/SplitWiseClone.xcdatamodeld`.

Known typo to be aware of: `CDExpenseSplit`'s amount field is named
`ownedAmount` (not `owedAmount`) in the schema — code that reads/writes it
uses the field as spelled.

## On-device ML

`ExpenseCategorizer` wraps a CoreML text classifier trained with Apple
CreateML on a small labeled dataset of expense titles → categories. Inference
runs fully on-device; no expense data is ever sent to an external API. Until
the trained `.mlmodel` is dropped into `ML/`, it falls back to a keyword
heuristic so the rest of the app builds and runs. See the TODO in
`ExpenseCategorizer.swift` for the CreateML training steps.

## Debt simplification

`Algorithms/DebtSimplifier.swift` nets every member's balance per currency,
then greedily matches the largest creditor against the largest debtor until
all balances are zero. Multi-currency debts are **never** netted against each
other (that would require a live FX rate). Covered by
`DebtSimplifierTests.swift`, including rounding-to-cents and multi-currency
isolation cases.

## Requirements

- Xcode 15+
- iOS 17+ deployment target (uses `NavigationStack`, `ContentUnavailableView`,
  `onChange(of:)` two-parameter closure API)
- An Apple Developer account with iCloud/CloudKit capability enabled if you
  want to test sync (not required to build/run locally)

## Setup

1. Clone the repo and open `SplitWiseClone.xcodeproj` in Xcode.
2. Select an iOS Simulator as the run destination (not "My Mac" — several
   view modifiers are iOS-only).
3. Build and run. The app works fully offline even before CloudKit
   entitlements are configured — sync just won't do anything until they are.

## Testing

```bash
xcodebuild test \
  -scheme SplitWiseClone \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or `Cmd+U` in Xcode. `DebtSimplifierTests` is the one worth reading first —
it covers the core reduction logic, rounding to cents, an already-settled
group, and multi-currency isolation.

## Status / TODOs

- [x] `.xcdatamodeld` created; `GroupListViewModel`/`GroupDetailViewModel`
      wired to real `NSFetchRequest`s and saves.
- [x] Create group, add expense, compute balances/settlements, mark settled
      all persist to Core Data.
- [ ] `settledAt` timestamp on `CDSettlement` — attribute not added yet, so
      settlement history has no recorded time.
- [ ] Settled debts can reappear in the settle-up list after new expenses
      are added, since balances are recomputed from raw expenses without
      checking prior settlements yet.
- [ ] Train and drop in the CreateML expense-category `.mlmodel`.
- [ ] Custom (non-equal) split entry in `AddExpenseView`.
- [ ] Login / auth — not started, no user model exists yet.
- [ ] UI tests.
- [ ] App icon / launch screen.

## License

MIT
