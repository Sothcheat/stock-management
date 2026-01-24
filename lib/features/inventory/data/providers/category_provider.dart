import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../inventory_repository.dart';

part 'category_provider.g.dart';

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  return ref.watch(inventoryRepositoryProvider);
}

@riverpod
Stream<List<Category>> categoryList(Ref ref) {
  return ref.watch(inventoryRepositoryProvider).watchCategories();
}
