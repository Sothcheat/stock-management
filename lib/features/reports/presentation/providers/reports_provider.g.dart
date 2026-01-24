// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$weeklyReportHash() => r'c8eb82e05cf3378ce969524bca37f126a4c28e4d';

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

/// See also [weeklyReport].
@ProviderFor(weeklyReport)
const weeklyReportProvider = WeeklyReportFamily();

/// See also [weeklyReport].
class WeeklyReportFamily extends Family<AsyncValue<List<DailyData>>> {
  /// See also [weeklyReport].
  const WeeklyReportFamily();

  /// See also [weeklyReport].
  WeeklyReportProvider call(DateTime targetDate) {
    return WeeklyReportProvider(targetDate);
  }

  @override
  WeeklyReportProvider getProviderOverride(
    covariant WeeklyReportProvider provider,
  ) {
    return call(provider.targetDate);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'weeklyReportProvider';
}

/// See also [weeklyReport].
class WeeklyReportProvider extends AutoDisposeStreamProvider<List<DailyData>> {
  /// See also [weeklyReport].
  WeeklyReportProvider(DateTime targetDate)
    : this._internal(
        (ref) => weeklyReport(ref as WeeklyReportRef, targetDate),
        from: weeklyReportProvider,
        name: r'weeklyReportProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$weeklyReportHash,
        dependencies: WeeklyReportFamily._dependencies,
        allTransitiveDependencies:
            WeeklyReportFamily._allTransitiveDependencies,
        targetDate: targetDate,
      );

  WeeklyReportProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Stream<List<DailyData>> Function(WeeklyReportRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WeeklyReportProvider._internal(
        (ref) => create(ref as WeeklyReportRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<DailyData>> createElement() {
    return _WeeklyReportProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WeeklyReportProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WeeklyReportRef on AutoDisposeStreamProviderRef<List<DailyData>> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _WeeklyReportProviderElement
    extends AutoDisposeStreamProviderElement<List<DailyData>>
    with WeeklyReportRef {
  _WeeklyReportProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as WeeklyReportProvider).targetDate;
}

String _$monthlyReportHash() => r'097949460e9a2bc64b8965e85f8eb8b18c4c6037';

/// See also [monthlyReport].
@ProviderFor(monthlyReport)
const monthlyReportProvider = MonthlyReportFamily();

/// See also [monthlyReport].
class MonthlyReportFamily extends Family<AsyncValue<List<DailyData>>> {
  /// See also [monthlyReport].
  const MonthlyReportFamily();

  /// See also [monthlyReport].
  MonthlyReportProvider call(DateTime targetDate) {
    return MonthlyReportProvider(targetDate);
  }

  @override
  MonthlyReportProvider getProviderOverride(
    covariant MonthlyReportProvider provider,
  ) {
    return call(provider.targetDate);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'monthlyReportProvider';
}

/// See also [monthlyReport].
class MonthlyReportProvider extends AutoDisposeStreamProvider<List<DailyData>> {
  /// See also [monthlyReport].
  MonthlyReportProvider(DateTime targetDate)
    : this._internal(
        (ref) => monthlyReport(ref as MonthlyReportRef, targetDate),
        from: monthlyReportProvider,
        name: r'monthlyReportProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$monthlyReportHash,
        dependencies: MonthlyReportFamily._dependencies,
        allTransitiveDependencies:
            MonthlyReportFamily._allTransitiveDependencies,
        targetDate: targetDate,
      );

  MonthlyReportProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Stream<List<DailyData>> Function(MonthlyReportRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MonthlyReportProvider._internal(
        (ref) => create(ref as MonthlyReportRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<DailyData>> createElement() {
    return _MonthlyReportProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyReportProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MonthlyReportRef on AutoDisposeStreamProviderRef<List<DailyData>> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _MonthlyReportProviderElement
    extends AutoDisposeStreamProviderElement<List<DailyData>>
    with MonthlyReportRef {
  _MonthlyReportProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as MonthlyReportProvider).targetDate;
}

String _$yearlyReportHash() => r'4ec1bdf441b6327d3f32e956678026439dcc9a0f';

/// See also [yearlyReport].
@ProviderFor(yearlyReport)
const yearlyReportProvider = YearlyReportFamily();

/// See also [yearlyReport].
class YearlyReportFamily extends Family<AsyncValue<List<DailyData>>> {
  /// See also [yearlyReport].
  const YearlyReportFamily();

  /// See also [yearlyReport].
  YearlyReportProvider call(DateTime targetDate) {
    return YearlyReportProvider(targetDate);
  }

  @override
  YearlyReportProvider getProviderOverride(
    covariant YearlyReportProvider provider,
  ) {
    return call(provider.targetDate);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'yearlyReportProvider';
}

/// See also [yearlyReport].
class YearlyReportProvider extends AutoDisposeStreamProvider<List<DailyData>> {
  /// See also [yearlyReport].
  YearlyReportProvider(DateTime targetDate)
    : this._internal(
        (ref) => yearlyReport(ref as YearlyReportRef, targetDate),
        from: yearlyReportProvider,
        name: r'yearlyReportProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$yearlyReportHash,
        dependencies: YearlyReportFamily._dependencies,
        allTransitiveDependencies:
            YearlyReportFamily._allTransitiveDependencies,
        targetDate: targetDate,
      );

  YearlyReportProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Stream<List<DailyData>> Function(YearlyReportRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: YearlyReportProvider._internal(
        (ref) => create(ref as YearlyReportRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<DailyData>> createElement() {
    return _YearlyReportProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is YearlyReportProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin YearlyReportRef on AutoDisposeStreamProviderRef<List<DailyData>> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _YearlyReportProviderElement
    extends AutoDisposeStreamProviderElement<List<DailyData>>
    with YearlyReportRef {
  _YearlyReportProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as YearlyReportProvider).targetDate;
}

String _$allTimeReportHash() => r'005ded87465141f1212dc7abce87c78f798855e2';

/// See also [allTimeReport].
@ProviderFor(allTimeReport)
const allTimeReportProvider = AllTimeReportFamily();

/// See also [allTimeReport].
class AllTimeReportFamily extends Family<AsyncValue<List<DailyData>>> {
  /// See also [allTimeReport].
  const AllTimeReportFamily();

  /// See also [allTimeReport].
  AllTimeReportProvider call(DateTime targetDate) {
    return AllTimeReportProvider(targetDate);
  }

  @override
  AllTimeReportProvider getProviderOverride(
    covariant AllTimeReportProvider provider,
  ) {
    return call(provider.targetDate);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'allTimeReportProvider';
}

/// See also [allTimeReport].
class AllTimeReportProvider extends AutoDisposeStreamProvider<List<DailyData>> {
  /// See also [allTimeReport].
  AllTimeReportProvider(DateTime targetDate)
    : this._internal(
        (ref) => allTimeReport(ref as AllTimeReportRef, targetDate),
        from: allTimeReportProvider,
        name: r'allTimeReportProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$allTimeReportHash,
        dependencies: AllTimeReportFamily._dependencies,
        allTransitiveDependencies:
            AllTimeReportFamily._allTransitiveDependencies,
        targetDate: targetDate,
      );

  AllTimeReportProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Stream<List<DailyData>> Function(AllTimeReportRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AllTimeReportProvider._internal(
        (ref) => create(ref as AllTimeReportRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<DailyData>> createElement() {
    return _AllTimeReportProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AllTimeReportProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AllTimeReportRef on AutoDisposeStreamProviderRef<List<DailyData>> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _AllTimeReportProviderElement
    extends AutoDisposeStreamProviderElement<List<DailyData>>
    with AllTimeReportRef {
  _AllTimeReportProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as AllTimeReportProvider).targetDate;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
