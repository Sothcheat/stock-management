// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_history_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$orderHistoryHash() => r'0f0e60118e21d5c49c1567ab9bcf1d5acab12936';

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

abstract class _$OrderHistory extends BuildlessNotifier<OrderHistoryState> {
  late final bool isArchived;

  OrderHistoryState build({bool isArchived = false});
}

/// See also [OrderHistory].
@ProviderFor(OrderHistory)
const orderHistoryProvider = OrderHistoryFamily();

/// See also [OrderHistory].
class OrderHistoryFamily extends Family<OrderHistoryState> {
  /// See also [OrderHistory].
  const OrderHistoryFamily();

  /// See also [OrderHistory].
  OrderHistoryProvider call({bool isArchived = false}) {
    return OrderHistoryProvider(isArchived: isArchived);
  }

  @override
  OrderHistoryProvider getProviderOverride(
    covariant OrderHistoryProvider provider,
  ) {
    return call(isArchived: provider.isArchived);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'orderHistoryProvider';
}

/// See also [OrderHistory].
class OrderHistoryProvider
    extends NotifierProviderImpl<OrderHistory, OrderHistoryState> {
  /// See also [OrderHistory].
  OrderHistoryProvider({bool isArchived = false})
    : this._internal(
        () => OrderHistory()..isArchived = isArchived,
        from: orderHistoryProvider,
        name: r'orderHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$orderHistoryHash,
        dependencies: OrderHistoryFamily._dependencies,
        allTransitiveDependencies:
            OrderHistoryFamily._allTransitiveDependencies,
        isArchived: isArchived,
      );

  OrderHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.isArchived,
  }) : super.internal();

  final bool isArchived;

  @override
  OrderHistoryState runNotifierBuild(covariant OrderHistory notifier) {
    return notifier.build(isArchived: isArchived);
  }

  @override
  Override overrideWith(OrderHistory Function() create) {
    return ProviderOverride(
      origin: this,
      override: OrderHistoryProvider._internal(
        () => create()..isArchived = isArchived,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        isArchived: isArchived,
      ),
    );
  }

  @override
  NotifierProviderElement<OrderHistory, OrderHistoryState> createElement() {
    return _OrderHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderHistoryProvider && other.isArchived == isArchived;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, isArchived.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OrderHistoryRef on NotifierProviderRef<OrderHistoryState> {
  /// The parameter `isArchived` of this provider.
  bool get isArchived;
}

class _OrderHistoryProviderElement
    extends NotifierProviderElement<OrderHistory, OrderHistoryState>
    with OrderHistoryRef {
  _OrderHistoryProviderElement(super.provider);

  @override
  bool get isArchived => (origin as OrderHistoryProvider).isArchived;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
