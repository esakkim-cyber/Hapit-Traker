import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  ExpenseRepository(this._db);

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<List<ExpenseCategoryModel>> getAllCategories() async {
    final rows = await _db.select(_db.expenseCategories).get();
    return rows.map((r) => ExpenseCategoryModel.fromDb(r)).toList();
  }

  Future<void> seedDefaultCategoriesIfEmpty() async {
    final count = _db.expenseCategories.id.count();
    final total = await (_db.selectOnly(_db.expenseCategories)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .getSingle();
    if (total > 0) return;

    await _db.batch((batch) {
      batch.insertAll(_db.expenseCategories, [
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Food',
          iconIndex: const Value(0),
          colorIndex: const Value(0),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Transport',
          iconIndex: const Value(1),
          colorIndex: const Value(1),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Shopping',
          iconIndex: const Value(2),
          colorIndex: const Value(2),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Bills',
          iconIndex: const Value(3),
          colorIndex: const Value(3),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Entertainment',
          iconIndex: const Value(4),
          colorIndex: const Value(4),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Health',
          iconIndex: const Value(5),
          colorIndex: const Value(5),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Other',
          iconIndex: const Value(6),
          colorIndex: const Value(6),
          isDefault: const Value(true),
          isIncome: const Value(false),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Salary',
          iconIndex: const Value(7),
          colorIndex: const Value(7),
          isDefault: const Value(true),
          isIncome: const Value(true),
        ),
        ExpenseCategoriesCompanion.insert(
          id: _uuid.v4(),
          name: 'Other Income',
          iconIndex: const Value(6),
          colorIndex: const Value(0),
          isDefault: const Value(true),
          isIncome: const Value(true),
        ),
      ]);
    });
  }

  Future<List<ExpenseModel>> getExpensesFiltered({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) async {
    final query = _db.select(_db.expenses);
    if (startDate != null) {
      final startStr = formatDate(startDate);
      query.where((t) => t.date.isBiggerOrEqualValue(startStr));
    }
    if (endDate != null) {
      final endStr = formatDate(endDate);
      query.where((t) => t.date.isSmallerOrEqualValue(endStr));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    query
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    return rows.map((r) => ExpenseModel.fromDb(r)).toList();
  }

  Future<double> getTotalIncomeForDateRange(DateTime start, DateTime end) async {
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final amount = _db.expenses.amount.sum();

    final result = await (_db.selectOnly(_db.expenses)
          ..join([
            innerJoin(
              _db.expenseCategories,
              _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
            ),
          ])
          ..addColumns([amount])
          ..where(_db.expenses.date.isBiggerOrEqualValue(startStr) &
              _db.expenses.date.isSmallerOrEqualValue(endStr) &
              _db.expenseCategories.isIncome.equals(true)))
        .map((row) => row.read(amount) ?? 0.0)
        .getSingleOrNull();

    return result ?? 0.0;
  }

  Future<double> getTotalExpenseForDateRange(DateTime start, DateTime end) async {
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final amount = _db.expenses.amount.sum();

    final result = await (_db.selectOnly(_db.expenses)
          ..join([
            innerJoin(
              _db.expenseCategories,
              _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
            ),
          ])
          ..addColumns([amount])
          ..where(_db.expenses.date.isBiggerOrEqualValue(startStr) &
              _db.expenses.date.isSmallerOrEqualValue(endStr) &
              _db.expenseCategories.isIncome.equals(false)))
        .map((row) => row.read(amount) ?? 0.0)
        .getSingleOrNull();

    return result ?? 0.0;
  }

  Future<String> insertExpense(ExpenseModel expense) async {
    if (expense.amount <= 0) {
      throw ArgumentError('Expense amount must be greater than 0');
    }
    final now = DateTime.now().toIso8601String();
    final id = expense.id.isNotEmpty ? expense.id : _uuid.v4();
    final createdAt = expense.createdAt.isNotEmpty ? expense.createdAt : now;
    final updatedAt = expense.updatedAt.isNotEmpty ? expense.updatedAt : now;

    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: id,
            categoryId: expense.categoryId,
            amount: expense.amount,
            description: Value(expense.description),
            date: expense.date,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );

    return id;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    if (expense.amount <= 0) {
      throw ArgumentError('Expense amount must be greater than 0');
    }
    final now = DateTime.now().toIso8601String();
    await (_db.update(_db.expenses)..where((t) => t.id.equals(expense.id))).write(
          ExpensesCompanion(
            categoryId: Value(expense.categoryId),
            amount: Value(expense.amount),
            description: Value(expense.description),
            date: Value(expense.date),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> deleteExpense(String expenseId) async {
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(expenseId))).go();
  }

  Stream<List<ExpenseCategoryModel>> watchAllCategories() {
    return _db.select(_db.expenseCategories).watch().map(
          (rows) => rows.map((r) => ExpenseCategoryModel.fromDb(r)).toList(),
        );
  }

  Stream<List<ExpenseModel>> watchFilteredExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) {
    final query = _db.select(_db.expenses);
    if (startDate != null) {
      final startStr = formatDate(startDate);
      query.where((t) => t.date.isBiggerOrEqualValue(startStr));
    }
    if (endDate != null) {
      final endStr = formatDate(endDate);
      query.where((t) => t.date.isSmallerOrEqualValue(endStr));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    query
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    return query.watch().map(
          (rows) => rows.map((r) => ExpenseModel.fromDb(r)).toList(),
        );
  }
}
