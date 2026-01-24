// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filteredInventoryHash() => r'3a299164e6ee50b0ec8af6887214a8de4210ee59';

/// See also [filteredInventory].
@ProviderFor(filteredInventory)
final filteredInventoryProvider =
    AutoDisposeProvider<AsyncValue<List<Product>>>.internal(
      filteredInventory,
      name: r'filteredInventoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$filteredInventoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredInventoryRef =
    AutoDisposeProviderRef<AsyncValue<List<Product>>>;
String _$inventoryFilterHash() => r'05756d3c2c18a2f4d85fee19aeadd0c3658de80c';

/// See also [InventoryFilter].
@ProviderFor(InventoryFilter)
final inventoryFilterProvider =
    AutoDisposeNotifierProvider<InventoryFilter, InventoryFilterState>.internal(
      InventoryFilter.new,
      name: r'inventoryFilterProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$inventoryFilterHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$InventoryFilter = AutoDisposeNotifier<InventoryFilterState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
