import 'package:drift/native.dart';
import 'package:flutter_enterprise_architecture/data/datasources/local/database/app_database.dart';

/// A fresh in-memory database. Close it with `await db.close()`.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());
