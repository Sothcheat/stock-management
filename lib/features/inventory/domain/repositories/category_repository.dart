import '../category.dart';

abstract class CategoryRepository {
  Future<String> addCategory(Category category);
  Stream<List<Category>> watchCategories();
  Future<void> deleteCategory(String id);
}
