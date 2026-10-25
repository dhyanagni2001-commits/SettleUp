# Training Data

Everything needed to rebuild `SplitWiseClone/ML/ExpenseCategoryClassifier.mlmodel`,
the on-device Core ML model that suggests a category from an expense title.

| File | What it is |
|---|---|
| `generate_dataset.py` | Builds `expense_categories.csv` (~7,900 titles) from per-category items and merchants. Seeded, so it's reproducible. Every category shares the same phrasing templates, so filler words like "for the group" carry no signal. |
| `expense_categories.csv` | Generated training data (git-ignored; rerun the script): `text`, `label` (an `ExpenseCategory` raw value). |
| `../SplitWiseCloneTests/evaluation.csv` | 84 hand-written titles (12 per category) that share no templates with the generator. Used only to score models, never to train. |
| `train.swift` | Trains two Create ML text classifiers (maxEnt and ELMo transfer learning), scores both on `evaluation.csv`, and writes the better one into `SplitWiseClone/ML/`. |

## Rebuild the model

From the repo root (macOS with Xcode installed):

```bash
python3 TrainingData/generate_dataset.py
swift TrainingData/train.swift
```

Training takes about 3 minutes, mostly the transfer-learning candidate. Xcode
compiles the `.mlmodel` automatically on the next build.

## Current results

| Model | Validation (generated data) | Hand-written held-out |
|---|---|---|
| **maxEnt (shipped, 28 KB)** | 99.2% | **78.6%** |
| ELMo transfer learning | 99.7% | 71.4% |

Validation accuracy is near-perfect because it comes from the same generator;
the held-out number is the honest one. In the app, the model's guess is used
when its confidence is at least 0.3, otherwise a keyword heuristic decides,
giving **77.4%** on the held-out set. The 0.3 threshold was picked by
comparing thresholds on that same set (see the `METRIC categorizer` lines from
`ExpenseCategorizerTests`), so treat 77% as slightly optimistic.

Typical misses are words the model has never seen (e.g. "Laundromat",
"Mercadona") and ambiguous phrases ("Coffee run" → Groceries). The suggestion
is only a default: people can always pick a different category.

To improve it, add real (or realistic) items and merchants to the vocabularies
in `generate_dataset.py`. Don't copy rows from `evaluation.csv` into training,
or the held-out score stops meaning anything.
