# Core Data Model — `SplitWiseClone.xcdatamodeld`

The `.xcdatamodeld` file is a binary-ish Xcode bundle and can't be hand-authored
outside the Core Data model editor, so it isn't included here. Create it in
Xcode (File > New > File > Data Model, named `SplitWiseClone`) with the
following entities, then set `PersistenceController`'s container name to match.

Remember to check **"Used with CloudKit"** in each entity's inspector, and
give every entity a `CD` prefix or codegen class as you prefer — the code in
this repo assumes the default class names below.

## Entities

### Group
| Attribute | Type | Notes |
|---|---|---|
| id | UUID | primary identifier |
| name | String | |
| createdAt | Date | |
Relationships: `members` (to-many Member), `expenses` (to-many Expense)

### Member
| Attribute | Type | Notes |
|---|---|---|
| id | UUID | |
| name | String | |
| userID | String | optional; account id of the person this member is ("me") |
Relationships: `group` (to-one Group), `paidExpenses` (to-many Expense), `splits` (to-many ExpenseSplit)

### Expense
| Attribute | Type | Notes |
|---|---|---|
| id | UUID | |
| title | String | |
| amount | Decimal | store in the expense's original currency |
| currencyCode | String | ISO 4217, e.g. "USD" |
| category | String | populated by the CoreML classifier |
| date | Date | |
Relationships: `group` (to-one Group), `paidBy` (to-one Member), `splits` (to-many ExpenseSplit)

### ExpenseSplit
One row per (expense, member) pair — how much of an expense a given member owes.
| Attribute | Type | Notes |
|---|---|---|
| id | UUID | |
| owedAmount | Decimal | |
Relationships: `expense` (to-one Expense), `member` (to-one Member)

### Settlement
A computed/recorded payment between two members that closes out a debt.
| Attribute | Type | Notes |
|---|---|---|
| id | UUID | |
| amount | Decimal | |
| currencyCode | String | |
| settledAt | Date | nil until marked paid |
Relationships: `group` (to-one Group), `fromMember` (to-one Member), `toMember` (to-one Member)

## Why CloudKit sync stays offline-first
`NSPersistentCloudKitContainer` treats the local SQLite store as the source of
truth and mirrors it to CloudKit in the background. Reads/writes always go to
the local store first, so the app is fully usable offline; CloudKit sync just
catches up whenever connectivity returns.
