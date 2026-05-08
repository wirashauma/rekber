import 'package:equatable/equatable.dart';

/// Product domain entity for seller catalog
class ProductEntity extends Equatable {
  final String id;
  final String sellerId;
  final String name;
  final String? description;
  final int price;
  final String? imageUrl;
  final String? category;
  final bool isActive;
  final DateTime createdAt;

  const ProductEntity({
    required this.id,
    required this.sellerId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    required this.isActive,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, price, isActive];
}
