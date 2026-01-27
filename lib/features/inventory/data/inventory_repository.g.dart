// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$inventoryRepositoryHash() =>
    r'89e98a24d84f1da603cbfd6a043a2e64ab24dece';

/// See also [inventoryRepository].
@ProviderFor(inventoryRepository)
final inventoryRepositoryProvider = Provider<InventoryRepository>.internal(
  inventoryRepository,
  name: r'inventoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$inventoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InventoryRepositoryRef = ProviderRef<InventoryRepository>;
String _$productsStreamHash() => r'4f8d499765553e18eadd0fe4de673a2a65e92b79';

/// See also [productsStream].
@ProviderFor(productsStream)
final productsStreamProvider =
    AutoDisposeStreamProvider<List<Product>>.internal(
      productsStream,
      name: r'productsStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductsStreamRef = AutoDisposeStreamProviderRef<List<Product>>;
String _$productsMapHash() => r'364687497aefb5e445ed7dfc6de12dc2eab9fb50';

/// See also [productsMap].
@ProviderFor(productsMap)
final productsMapProvider =
    AutoDisposeStreamProvider<Map<String, Product>>.internal(
      productsMap,
      name: r'productsMapProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productsMapHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductsMapRef = AutoDisposeStreamProviderRef<Map<String, Product>>;
String _$productsMapByIdHash() => r'd670d99b8d65a93bf6199e922c84e847abe07242';

/// See also [productsMapById].
@ProviderFor(productsMapById)
final productsMapByIdProvider =
    AutoDisposeStreamProvider<Map<String, Product>>.internal(
      productsMapById,
      name: r'productsMapByIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productsMapByIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductsMapByIdRef = AutoDisposeStreamProviderRef<Map<String, Product>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
