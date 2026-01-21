import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  Map<String, dynamic> toFirestore() {
    return {'name': name};
  }

  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Category(id: doc.id, name: data['name'] ?? '');
  }
}
