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
String _$orderStreamHash() => r'306366356da6a433974605e668cf988a1e0f9ca3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [orderStream].
@ProviderFor(orderStream)
const orderStreamProvider = OrderStreamFamily();

/// See also [orderStream].
class OrderStreamFamily extends Family<AsyncValue<OrderModel?>> {
  /// See also [orderStream].
  const OrderStreamFamily();

  /// See also [orderStream].
  OrderStreamProvider call(String id) {
    return OrderStreamProvider(id);
  }

  @override
  OrderStreamProvider getProviderOverride(
    covariant OrderStreamProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'orderStreamProvider';
}

/// See also [orderStream].
class OrderStreamProvider extends AutoDisposeStreamProvider<OrderModel?> {
  /// See also [orderStream].
  OrderStreamProvider(String id)
    : this._internal(
        (ref) => orderStream(ref as OrderStreamRef, id),
        from: orderStreamProvider,
        name: r'orderStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$orderStreamHash,
        dependencies: OrderStreamFamily._dependencies,
        allTransitiveDependencies: OrderStreamFamily._allTransitiveDependencies,
        id: id,
      );

  OrderStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    Stream<OrderModel?> Function(OrderStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OrderStreamProvider._internal(
        (ref) => create(ref as OrderStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<OrderModel?> createElement() {
    return _OrderStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderStreamProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OrderStreamRef on AutoDisposeStreamProviderRef<OrderModel?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _OrderStreamProviderElement
    extends AutoDisposeStreamProviderElement<OrderModel?>
    with OrderStreamRef {
  _OrderStreamProviderElement(super.provider);

  @override
  String get id => (origin as OrderStreamProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
