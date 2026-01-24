// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_orders_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ordersRepositoryHash() => r'a6631388736324921904e6b50943afef8f0a8601';

/// See also [ordersRepository].
@ProviderFor(ordersRepository)
final ordersRepositoryProvider = Provider<OrderRepository>.internal(
  ordersRepository,
  name: r'ordersRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ordersRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OrdersRepositoryRef = ProviderRef<OrderRepository>;
String _$ordersStreamHash() => r'28750627e24ae8a0549fe1df7d87ca0bfe7b5d2c';

/// See also [ordersStream].
@ProviderFor(ordersStream)
final ordersStreamProvider =
    AutoDisposeStreamProvider<List<OrderModel>>.internal(
      ordersStream,
      name: r'ordersStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$ordersStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OrdersStreamRef = AutoDisposeStreamProviderRef<List<OrderModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
