import '../database/app_database.dart';

class ExpenseCategoryModel {
  final String id;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isDefault;
  final bool isIncome;

  const ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.iconIndex = 0,
    this.colorIndex = 0,
    this.isDefault = false,
    this.isIncome = false,
  });

  factory ExpenseCategoryModel.fromDb(ExpenseCategory row) {
    return ExpenseCategoryModel(
      id: row.id,
      name: row.name,
      iconIndex: row.iconIndex,
      colorIndex: row.colorIndex,
      isDefault: row.isDefault,
      isIncome: row.isIncome,
    );
  }

  ExpenseCategoriesCompanion toInsertCompanion() {
    return ExpenseCategoriesCompanion.insert(
      id: id,
      name: name,
      iconIndex: Value(iconIndex),
      colorIndex: Value(colorIndex),
      isDefault: Value(isDefault),
      isIncome: Value(isIncome),
    );
  }

  ExpenseCategoryModel copyWith({
    String? id,
    String? name,
    int? iconIndex,
    int? colorIndex,
    bool? isDefault,
    bool? isIncome,
  }) {
    return ExpenseCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconIndex: iconIndex ?? this.iconIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      isDefault: isDefault ?? this.isDefault,
      isIncome: isIncome ?? this.isIncome,
    );
  }
}

class ExpenseModel {
  final String id;
  final String categoryId;
  final String date;
  final String createdAt;
  final String updatedAt;
  final double amount;
  final String? description;

  const ExpenseModel({
    required this.id,
    required this.categoryId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.amount,
    this.description,
  });

  factory ExpenseModel.fromDb(Expense row) {
    return ExpenseModel(
      id: row.id,
      categoryId: row.categoryId,
      date: row.date,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      amount: row.amount,
      description: row.description,
    );
  }

  ExpensesCompanion toInsertCompanion() {
    return ExpensesCompanion.insert(
      id: id,
      categoryId: categoryId,
      amount: amount,
      description: Value(description),
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? categoryId,
    String? date,
    String? createdAt,
    String? updatedAt,
    double? amount,
    String? description,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }
}
