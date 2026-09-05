import 'package:flutter/material.dart';

import '../models/category.dart';

class CategoriesScreen extends StatefulWidget {
  final String title;
  final Future<List<Category>> Function() fetchCategories;
  final void Function(BuildContext context, Category category) onCategoryTap;

  const CategoriesScreen({
    super.key,
    required this.title,
    required this.fetchCategories,
    required this.onCategoryTap,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onCategoryTap(context, category),
              );
            },
          );
        },
      ),
    );
  }
}
