import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String? icon;

  const Category({required this.id, required this.name, this.icon});

  Map<String, dynamic> toMap() {
    return {'name': name, 'icon': icon};
  }

  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Category(id: doc.id, name: data['name'] ?? '', icon: data['icon']);
  }

  // Helper for empty/new
  factory Category.empty() {
    return const Category(id: '', name: '');
  }
}
