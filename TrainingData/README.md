# Training Data

`expense_categories_seed.csv` is a small starter dataset (~26 rows) for the
CreateML text classifier referenced in `SplitWiseClone/ML/ExpenseCategorizer.swift`.
It's enough to get a model exporting end-to-end, but too small to be
accurate — add more real (or realistic) rows per category before training
the model you actually ship.

## Training steps

1. Open **Create ML.app** (comes with Xcode; also launchable via
   Xcode → Open Developer Tool → Create ML).
2. New Project → **Text Classifier**.
3. Drag in this CSV as the training data, with `text` as the input column
   and `label` as the target column.
4. Train, check the evaluation metrics tab, then **Export** as
   `ExpenseCategoryClassifier.mlmodel`.
5. Drag the exported `.mlmodel` into the `SplitWiseClone/ML/` folder in
   Xcode (check "copy items if needed" and add it to the app target).
   Xcode auto-generates a Swift wrapper class with the same name.
6. In `ExpenseCategorizer.swift`, flip `modelIsAvailable` to `true` and
   uncomment the real inference call.
