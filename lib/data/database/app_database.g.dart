// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSystemDefaultMeta = const VerificationMeta(
    'isSystemDefault',
  );
  @override
  late final GeneratedColumn<bool> isSystemDefault = GeneratedColumn<bool>(
    'is_system_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    name,
    colorArgb,
    icon,
    orderIndex,
    isSystemDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('is_system_default')) {
      context.handle(
        _isSystemDefaultMeta,
        isSystemDefault.isAcceptableOrUnknown(
          data['is_system_default']!,
          _isSystemDefaultMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      isSystemDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system_default'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String name;
  final int colorArgb;

  /// 图标**标识串**，不存二进制 —— 图标资源应随版本走，
  /// 存进库会让换图标变成一次数据迁移。
  final String icon;
  final int orderIndex;

  /// 「未分类」这条不可删（settings-spec §4）。
  final bool isSystemDefault;
  const CategoryRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.icon,
    required this.orderIndex,
    required this.isSystemDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_argb'] = Variable<int>(colorArgb);
    map['icon'] = Variable<String>(icon);
    map['order_index'] = Variable<int>(orderIndex);
    map['is_system_default'] = Variable<bool>(isSystemDefault);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      name: Value(name),
      colorArgb: Value(colorArgb),
      icon: Value(icon),
      orderIndex: Value(orderIndex),
      isSystemDefault: Value(isSystemDefault),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      icon: serializer.fromJson<String>(json['icon']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      isSystemDefault: serializer.fromJson<bool>(json['isSystemDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'icon': serializer.toJson<String>(icon),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'isSystemDefault': serializer.toJson<bool>(isSystemDefault),
    };
  }

  CategoryRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? name,
    int? colorArgb,
    String? icon,
    int? orderIndex,
    bool? isSystemDefault,
  }) => CategoryRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    icon: icon ?? this.icon,
    orderIndex: orderIndex ?? this.orderIndex,
    isSystemDefault: isSystemDefault ?? this.isSystemDefault,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      icon: data.icon.present ? data.icon.value : this.icon,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      isSystemDefault: data.isSystemDefault.present
          ? data.isSystemDefault.value
          : this.isSystemDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('icon: $icon, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isSystemDefault: $isSystemDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    name,
    colorArgb,
    icon,
    orderIndex,
    isSystemDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorArgb == this.colorArgb &&
          other.icon == this.icon &&
          other.orderIndex == this.orderIndex &&
          other.isSystemDefault == this.isSystemDefault);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorArgb;
  final Value<String> icon;
  final Value<int> orderIndex;
  final Value<bool> isSystemDefault;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.icon = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.isSystemDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String name,
    required int colorArgb,
    required String icon,
    required int orderIndex,
    this.isSystemDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       name = Value(name),
       colorArgb = Value(colorArgb),
       icon = Value(icon),
       orderIndex = Value(orderIndex);
  static Insertable<CategoryRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorArgb,
    Expression<String>? icon,
    Expression<int>? orderIndex,
    Expression<bool>? isSystemDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (icon != null) 'icon': icon,
      if (orderIndex != null) 'order_index': orderIndex,
      if (isSystemDefault != null) 'is_system_default': isSystemDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorArgb,
    Value<String>? icon,
    Value<int>? orderIndex,
    Value<bool>? isSystemDefault,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
      icon: icon ?? this.icon,
      orderIndex: orderIndex ?? this.orderIndex,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (isSystemDefault.present) {
      map['is_system_default'] = Variable<bool>(isSystemDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('icon: $icon, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('isSystemDefault: $isSystemDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _statusBeforeArchiveMeta =
      const VerificationMeta('statusBeforeArchive');
  @override
  late final GeneratedColumn<String> statusBeforeArchive =
      GeneratedColumn<String>(
        'status_before_archive',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _planDateMeta = const VerificationMeta(
    'planDate',
  );
  @override
  late final GeneratedColumn<String> planDate = GeneratedColumn<String>(
    'plan_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceExDatesMeta = const VerificationMeta(
    'recurrenceExDates',
  );
  @override
  late final GeneratedColumn<String> recurrenceExDates =
      GeneratedColumn<String>(
        'recurrence_ex_dates',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _splitFromTaskIdMeta = const VerificationMeta(
    'splitFromTaskId',
  );
  @override
  late final GeneratedColumn<String> splitFromTaskId = GeneratedColumn<String>(
    'split_from_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    title,
    note,
    kind,
    categoryId,
    priority,
    status,
    statusBeforeArchive,
    isAllDay,
    planDate,
    startMinute,
    endDate,
    endMinute,
    timeZoneId,
    recurrenceRule,
    recurrenceExDates,
    splitFromTaskId,
    colorArgb,
    icon,
    sortOrder,
    completedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('status_before_archive')) {
      context.handle(
        _statusBeforeArchiveMeta,
        statusBeforeArchive.isAcceptableOrUnknown(
          data['status_before_archive']!,
          _statusBeforeArchiveMeta,
        ),
      );
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('plan_date')) {
      context.handle(
        _planDateMeta,
        planDate.isAcceptableOrUnknown(data['plan_date']!, _planDateMeta),
      );
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeZoneIdMeta);
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_ex_dates')) {
      context.handle(
        _recurrenceExDatesMeta,
        recurrenceExDates.isAcceptableOrUnknown(
          data['recurrence_ex_dates']!,
          _recurrenceExDatesMeta,
        ),
      );
    }
    if (data.containsKey('split_from_task_id')) {
      context.handle(
        _splitFromTaskIdMeta,
        splitFromTaskId.isAcceptableOrUnknown(
          data['split_from_task_id']!,
          _splitFromTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      statusBeforeArchive: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_before_archive'],
      ),
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      planDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_date'],
      ),
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      recurrenceExDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_ex_dates'],
      ),
      splitFromTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}split_from_task_id'],
      ),
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String title;
  final String? note;

  /// `single` | `staged`。**不用 Drift 的 enum 列**：
  /// `intEnum` 把序号写进库，将来枚举重排会静默改写全部历史数据；
  /// `textEnum` 虽存名字，但重命名同样破坏存量。存字符串并在 mapper 里
  /// 显式转换，未知值可被发现而不是被当成 0。
  final String kind;

  /// 删分类不删任务（FR-CFG-03）。
  final String? categoryId;

  /// 0 无 / 1 低 / 2 普通 / 3 高 / 4 紧急。
  final int priority;

  /// `pending`|`inProgress`|`done`|`skipped`。
  ///
  /// **重复任务此列恒为 `pending`**，真实状态在 `occurrence_overrides`（§4.3）。
  final String status;

  /// 归档时快照的 [status]，取消归档时还原；非归档态恒为 NULL。
  final String? statusBeforeArchive;
  final bool isAllDay;

  /// `yyyy-MM-dd`。重复任务即 DTSTART 的日期。
  final String? planDate;

  /// 0..1439，`isAllDay=1` 时为 NULL。
  final int? startMinute;
  final String? endDate;
  final int? endMinute;

  /// IANA 时区，创建时的。**存墙钟 + 时区而非 UTC 时间戳**，理由见 ADR-0005。
  final String timeZoneId;

  /// RFC 5545 `RRULE:` 串。NULL = 不重复。
  ///
  /// **必须是 `encodeRrule()` 产出的规范形**（含 UNTIL 时必带 `Z`），
  /// 不得直接存外部原串 —— recurrence-engine §2.3。
  final String? recurrenceRule;

  /// JSON 数组。**V1 不参与展开**，仅作导入 .ics 的原始留档（§4.5）。
  final String? recurrenceExDates;

  /// 「本次及以后」分裂的溯源（§4.4）。
  final String? splitFromTaskId;
  final int? colorArgb;
  final String? icon;

  /// 手动排序。用浮点便于在两条之间插入而不重排整表。
  final double sortOrder;
  final int? completedAt;

  /// 非空即已归档。**归档不是 `status` 的取值** —— 否则重复任务
  /// （status 恒为 pending）将永远无法归档。task-lifecycle §1.1。
  final int? archivedAt;
  const TaskRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.title,
    this.note,
    required this.kind,
    this.categoryId,
    required this.priority,
    required this.status,
    this.statusBeforeArchive,
    required this.isAllDay,
    this.planDate,
    this.startMinute,
    this.endDate,
    this.endMinute,
    required this.timeZoneId,
    this.recurrenceRule,
    this.recurrenceExDates,
    this.splitFromTaskId,
    this.colorArgb,
    this.icon,
    required this.sortOrder,
    this.completedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || statusBeforeArchive != null) {
      map['status_before_archive'] = Variable<String>(statusBeforeArchive);
    }
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || planDate != null) {
      map['plan_date'] = Variable<String>(planDate);
    }
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    map['time_zone_id'] = Variable<String>(timeZoneId);
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceExDates != null) {
      map['recurrence_ex_dates'] = Variable<String>(recurrenceExDates);
    }
    if (!nullToAbsent || splitFromTaskId != null) {
      map['split_from_task_id'] = Variable<String>(splitFromTaskId);
    }
    if (!nullToAbsent || colorArgb != null) {
      map['color_argb'] = Variable<int>(colorArgb);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      kind: Value(kind),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      priority: Value(priority),
      status: Value(status),
      statusBeforeArchive: statusBeforeArchive == null && nullToAbsent
          ? const Value.absent()
          : Value(statusBeforeArchive),
      isAllDay: Value(isAllDay),
      planDate: planDate == null && nullToAbsent
          ? const Value.absent()
          : Value(planDate),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      timeZoneId: Value(timeZoneId),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceExDates: recurrenceExDates == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceExDates),
      splitFromTaskId: splitFromTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(splitFromTaskId),
      colorArgb: colorArgb == null && nullToAbsent
          ? const Value.absent()
          : Value(colorArgb),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      kind: serializer.fromJson<String>(json['kind']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      statusBeforeArchive: serializer.fromJson<String?>(
        json['statusBeforeArchive'],
      ),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      planDate: serializer.fromJson<String?>(json['planDate']),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
      recurrenceExDates: serializer.fromJson<String?>(
        json['recurrenceExDates'],
      ),
      splitFromTaskId: serializer.fromJson<String?>(json['splitFromTaskId']),
      colorArgb: serializer.fromJson<int?>(json['colorArgb']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'kind': serializer.toJson<String>(kind),
      'categoryId': serializer.toJson<String?>(categoryId),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<String>(status),
      'statusBeforeArchive': serializer.toJson<String?>(statusBeforeArchive),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'planDate': serializer.toJson<String?>(planDate),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endDate': serializer.toJson<String?>(endDate),
      'endMinute': serializer.toJson<int?>(endMinute),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
      'recurrenceExDates': serializer.toJson<String?>(recurrenceExDates),
      'splitFromTaskId': serializer.toJson<String?>(splitFromTaskId),
      'colorArgb': serializer.toJson<int?>(colorArgb),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'completedAt': serializer.toJson<int?>(completedAt),
      'archivedAt': serializer.toJson<int?>(archivedAt),
    };
  }

  TaskRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? title,
    Value<String?> note = const Value.absent(),
    String? kind,
    Value<String?> categoryId = const Value.absent(),
    int? priority,
    String? status,
    Value<String?> statusBeforeArchive = const Value.absent(),
    bool? isAllDay,
    Value<String?> planDate = const Value.absent(),
    Value<int?> startMinute = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    String? timeZoneId,
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceExDates = const Value.absent(),
    Value<String?> splitFromTaskId = const Value.absent(),
    Value<int?> colorArgb = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    double? sortOrder,
    Value<int?> completedAt = const Value.absent(),
    Value<int?> archivedAt = const Value.absent(),
  }) => TaskRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    kind: kind ?? this.kind,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    statusBeforeArchive: statusBeforeArchive.present
        ? statusBeforeArchive.value
        : this.statusBeforeArchive,
    isAllDay: isAllDay ?? this.isAllDay,
    planDate: planDate.present ? planDate.value : this.planDate,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endDate: endDate.present ? endDate.value : this.endDate,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceExDates: recurrenceExDates.present
        ? recurrenceExDates.value
        : this.recurrenceExDates,
    splitFromTaskId: splitFromTaskId.present
        ? splitFromTaskId.value
        : this.splitFromTaskId,
    colorArgb: colorArgb.present ? colorArgb.value : this.colorArgb,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      kind: data.kind.present ? data.kind.value : this.kind,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      statusBeforeArchive: data.statusBeforeArchive.present
          ? data.statusBeforeArchive.value
          : this.statusBeforeArchive,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      planDate: data.planDate.present ? data.planDate.value : this.planDate,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceExDates: data.recurrenceExDates.present
          ? data.recurrenceExDates.value
          : this.recurrenceExDates,
      splitFromTaskId: data.splitFromTaskId.present
          ? data.splitFromTaskId.value
          : this.splitFromTaskId,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('statusBeforeArchive: $statusBeforeArchive, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('planDate: $planDate, ')
          ..write('startMinute: $startMinute, ')
          ..write('endDate: $endDate, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceExDates: $recurrenceExDates, ')
          ..write('splitFromTaskId: $splitFromTaskId, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('completedAt: $completedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    title,
    note,
    kind,
    categoryId,
    priority,
    status,
    statusBeforeArchive,
    isAllDay,
    planDate,
    startMinute,
    endDate,
    endMinute,
    timeZoneId,
    recurrenceRule,
    recurrenceExDates,
    splitFromTaskId,
    colorArgb,
    icon,
    sortOrder,
    completedAt,
    archivedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.title == this.title &&
          other.note == this.note &&
          other.kind == this.kind &&
          other.categoryId == this.categoryId &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.statusBeforeArchive == this.statusBeforeArchive &&
          other.isAllDay == this.isAllDay &&
          other.planDate == this.planDate &&
          other.startMinute == this.startMinute &&
          other.endDate == this.endDate &&
          other.endMinute == this.endMinute &&
          other.timeZoneId == this.timeZoneId &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceExDates == this.recurrenceExDates &&
          other.splitFromTaskId == this.splitFromTaskId &&
          other.colorArgb == this.colorArgb &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.completedAt == this.completedAt &&
          other.archivedAt == this.archivedAt);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> title;
  final Value<String?> note;
  final Value<String> kind;
  final Value<String?> categoryId;
  final Value<int> priority;
  final Value<String> status;
  final Value<String?> statusBeforeArchive;
  final Value<bool> isAllDay;
  final Value<String?> planDate;
  final Value<int?> startMinute;
  final Value<String?> endDate;
  final Value<int?> endMinute;
  final Value<String> timeZoneId;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceExDates;
  final Value<String?> splitFromTaskId;
  final Value<int?> colorArgb;
  final Value<String?> icon;
  final Value<double> sortOrder;
  final Value<int?> completedAt;
  final Value<int?> archivedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.kind = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.statusBeforeArchive = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.planDate = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceExDates = const Value.absent(),
    this.splitFromTaskId = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String title,
    this.note = const Value.absent(),
    required String kind,
    this.categoryId = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.statusBeforeArchive = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.planDate = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endMinute = const Value.absent(),
    required String timeZoneId,
    this.recurrenceRule = const Value.absent(),
    this.recurrenceExDates = const Value.absent(),
    this.splitFromTaskId = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       title = Value(title),
       kind = Value(kind),
       timeZoneId = Value(timeZoneId);
  static Insertable<TaskRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? note,
    Expression<String>? kind,
    Expression<String>? categoryId,
    Expression<int>? priority,
    Expression<String>? status,
    Expression<String>? statusBeforeArchive,
    Expression<bool>? isAllDay,
    Expression<String>? planDate,
    Expression<int>? startMinute,
    Expression<String>? endDate,
    Expression<int>? endMinute,
    Expression<String>? timeZoneId,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceExDates,
    Expression<String>? splitFromTaskId,
    Expression<int>? colorArgb,
    Expression<String>? icon,
    Expression<double>? sortOrder,
    Expression<int>? completedAt,
    Expression<int>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (kind != null) 'kind': kind,
      if (categoryId != null) 'category_id': categoryId,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (statusBeforeArchive != null)
        'status_before_archive': statusBeforeArchive,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (planDate != null) 'plan_date': planDate,
      if (startMinute != null) 'start_minute': startMinute,
      if (endDate != null) 'end_date': endDate,
      if (endMinute != null) 'end_minute': endMinute,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceExDates != null) 'recurrence_ex_dates': recurrenceExDates,
      if (splitFromTaskId != null) 'split_from_task_id': splitFromTaskId,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (completedAt != null) 'completed_at': completedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? title,
    Value<String?>? note,
    Value<String>? kind,
    Value<String?>? categoryId,
    Value<int>? priority,
    Value<String>? status,
    Value<String?>? statusBeforeArchive,
    Value<bool>? isAllDay,
    Value<String?>? planDate,
    Value<int?>? startMinute,
    Value<String?>? endDate,
    Value<int?>? endMinute,
    Value<String>? timeZoneId,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceExDates,
    Value<String?>? splitFromTaskId,
    Value<int?>? colorArgb,
    Value<String?>? icon,
    Value<double>? sortOrder,
    Value<int?>? completedAt,
    Value<int?>? archivedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      kind: kind ?? this.kind,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      statusBeforeArchive: statusBeforeArchive ?? this.statusBeforeArchive,
      isAllDay: isAllDay ?? this.isAllDay,
      planDate: planDate ?? this.planDate,
      startMinute: startMinute ?? this.startMinute,
      endDate: endDate ?? this.endDate,
      endMinute: endMinute ?? this.endMinute,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceExDates: recurrenceExDates ?? this.recurrenceExDates,
      splitFromTaskId: splitFromTaskId ?? this.splitFromTaskId,
      colorArgb: colorArgb ?? this.colorArgb,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (statusBeforeArchive.present) {
      map['status_before_archive'] = Variable<String>(
        statusBeforeArchive.value,
      );
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (planDate.present) {
      map['plan_date'] = Variable<String>(planDate.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceExDates.present) {
      map['recurrence_ex_dates'] = Variable<String>(recurrenceExDates.value);
    }
    if (splitFromTaskId.present) {
      map['split_from_task_id'] = Variable<String>(splitFromTaskId.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('statusBeforeArchive: $statusBeforeArchive, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('planDate: $planDate, ')
          ..write('startMinute: $startMinute, ')
          ..write('endDate: $endDate, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceExDates: $recurrenceExDates, ')
          ..write('splitFromTaskId: $splitFromTaskId, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('completedAt: $completedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StagesTable extends Stages with TableInfo<$StagesTable, StageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMinutesMeta =
      const VerificationMeta('startOffsetMinutes');
  @override
  late final GeneratedColumn<int> startOffsetMinutes = GeneratedColumn<int>(
    'start_offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    title,
    orderIndex,
    startOffsetMinutes,
    durationMinutes,
    colorArgb,
    status,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stages';
  @override
  VerificationContext validateIntegrity(
    Insertable<StageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('start_offset_minutes')) {
      context.handle(
        _startOffsetMinutesMeta,
        startOffsetMinutes.isAcceptableOrUnknown(
          data['start_offset_minutes']!,
          _startOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      startOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset_minutes'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      ),
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $StagesTable createAlias(String alias) {
    return $StagesTable(attachedDatabase, alias);
  }
}

class StageRow extends DataClass implements Insertable<StageRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String taskId;
  final String title;

  /// 从 0 起连续。
  final int orderIndex;

  /// 相对任务（或该次发生）开始的分钟偏移。
  final int? startOffsetMinutes;
  final int? durationMinutes;
  final int? colorArgb;

  /// 仅非重复任务使用；重复任务的阶段状态在 `stage_occurrence_states`。
  final String status;
  final int? completedAt;
  const StageRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.taskId,
    required this.title,
    required this.orderIndex,
    this.startOffsetMinutes,
    this.durationMinutes,
    this.colorArgb,
    required this.status,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || startOffsetMinutes != null) {
      map['start_offset_minutes'] = Variable<int>(startOffsetMinutes);
    }
    if (!nullToAbsent || durationMinutes != null) {
      map['duration_minutes'] = Variable<int>(durationMinutes);
    }
    if (!nullToAbsent || colorArgb != null) {
      map['color_argb'] = Variable<int>(colorArgb);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  StagesCompanion toCompanion(bool nullToAbsent) {
    return StagesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      orderIndex: Value(orderIndex),
      startOffsetMinutes: startOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(startOffsetMinutes),
      durationMinutes: durationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMinutes),
      colorArgb: colorArgb == null && nullToAbsent
          ? const Value.absent()
          : Value(colorArgb),
      status: Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory StageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StageRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      startOffsetMinutes: serializer.fromJson<int?>(json['startOffsetMinutes']),
      durationMinutes: serializer.fromJson<int?>(json['durationMinutes']),
      colorArgb: serializer.fromJson<int?>(json['colorArgb']),
      status: serializer.fromJson<String>(json['status']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'startOffsetMinutes': serializer.toJson<int?>(startOffsetMinutes),
      'durationMinutes': serializer.toJson<int?>(durationMinutes),
      'colorArgb': serializer.toJson<int?>(colorArgb),
      'status': serializer.toJson<String>(status),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  StageRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? taskId,
    String? title,
    int? orderIndex,
    Value<int?> startOffsetMinutes = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> colorArgb = const Value.absent(),
    String? status,
    Value<int?> completedAt = const Value.absent(),
  }) => StageRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    orderIndex: orderIndex ?? this.orderIndex,
    startOffsetMinutes: startOffsetMinutes.present
        ? startOffsetMinutes.value
        : this.startOffsetMinutes,
    durationMinutes: durationMinutes.present
        ? durationMinutes.value
        : this.durationMinutes,
    colorArgb: colorArgb.present ? colorArgb.value : this.colorArgb,
    status: status ?? this.status,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  StageRow copyWithCompanion(StagesCompanion data) {
    return StageRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      startOffsetMinutes: data.startOffsetMinutes.present
          ? data.startOffsetMinutes.value
          : this.startOffsetMinutes,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startOffsetMinutes: $startOffsetMinutes, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    title,
    orderIndex,
    startOffsetMinutes,
    durationMinutes,
    colorArgb,
    status,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.orderIndex == this.orderIndex &&
          other.startOffsetMinutes == this.startOffsetMinutes &&
          other.durationMinutes == this.durationMinutes &&
          other.colorArgb == this.colorArgb &&
          other.status == this.status &&
          other.completedAt == this.completedAt);
}

class StagesCompanion extends UpdateCompanion<StageRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<int> orderIndex;
  final Value<int?> startOffsetMinutes;
  final Value<int?> durationMinutes;
  final Value<int?> colorArgb;
  final Value<String> status;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const StagesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startOffsetMinutes = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StagesCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String taskId,
    required String title,
    required int orderIndex,
    this.startOffsetMinutes = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       orderIndex = Value(orderIndex);
  static Insertable<StageRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<int>? orderIndex,
    Expression<int>? startOffsetMinutes,
    Expression<int>? durationMinutes,
    Expression<int>? colorArgb,
    Expression<String>? status,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (orderIndex != null) 'order_index': orderIndex,
      if (startOffsetMinutes != null)
        'start_offset_minutes': startOffsetMinutes,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StagesCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<int>? orderIndex,
    Value<int?>? startOffsetMinutes,
    Value<int?>? durationMinutes,
    Value<int?>? colorArgb,
    Value<String>? status,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return StagesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      startOffsetMinutes: startOffsetMinutes ?? this.startOffsetMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      colorArgb: colorArgb ?? this.colorArgb,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (startOffsetMinutes.present) {
      map['start_offset_minutes'] = Variable<int>(startOffsetMinutes.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StagesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startOffsetMinutes: $startOffsetMinutes, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChecklistItemsTable extends ChecklistItems
    with TableInfo<$ChecklistItemsTable, ChecklistItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    title,
    isDone,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChecklistItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChecklistItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChecklistItemRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $ChecklistItemsTable createAlias(String alias) {
    return $ChecklistItemsTable(attachedDatabase, alias);
  }
}

class ChecklistItemRow extends DataClass
    implements Insertable<ChecklistItemRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int orderIndex;
  const ChecklistItemRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.taskId,
    required this.title,
    required this.isDone,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  ChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return ChecklistItemsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      isDone: Value(isDone),
      orderIndex: Value(orderIndex),
    );
  }

  factory ChecklistItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChecklistItemRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  ChecklistItemRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? taskId,
    String? title,
    bool? isDone,
    int? orderIndex,
  }) => ChecklistItemRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  ChecklistItemRow copyWithCompanion(ChecklistItemsCompanion data) {
    return ChecklistItemRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    title,
    isDone,
    orderIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChecklistItemRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.isDone == this.isDone &&
          other.orderIndex == this.orderIndex);
}

class ChecklistItemsCompanion extends UpdateCompanion<ChecklistItemRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<bool> isDone;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const ChecklistItemsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChecklistItemsCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String taskId,
    required String title,
    this.isDone = const Value.absent(),
    required int orderIndex,
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       orderIndex = Value(orderIndex);
  static Insertable<ChecklistItemRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<bool>? isDone,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChecklistItemsCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<bool>? isDone,
    Value<int>? orderIndex,
    Value<int>? rowid,
  }) {
    return ChecklistItemsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChecklistItemsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccurrenceOverridesTable extends OccurrenceOverrides
    with TableInfo<$OccurrenceOverridesTable, OccurrenceOverrideRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccurrenceOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _occurrenceKeyMeta = const VerificationMeta(
    'occurrenceKey',
  );
  @override
  late final GeneratedColumn<String> occurrenceKey = GeneratedColumn<String>(
    'occurrence_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleOverrideMeta = const VerificationMeta(
    'titleOverride',
  );
  @override
  late final GeneratedColumn<String> titleOverride = GeneratedColumn<String>(
    'title_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteOverrideMeta = const VerificationMeta(
    'noteOverride',
  );
  @override
  late final GeneratedColumn<String> noteOverride = GeneratedColumn<String>(
    'note_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planDateOverrideMeta = const VerificationMeta(
    'planDateOverride',
  );
  @override
  late final GeneratedColumn<String> planDateOverride = GeneratedColumn<String>(
    'plan_date_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMinuteOverrideMeta =
      const VerificationMeta('startMinuteOverride');
  @override
  late final GeneratedColumn<int> startMinuteOverride = GeneratedColumn<int>(
    'start_minute_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateOverrideMeta = const VerificationMeta(
    'endDateOverride',
  );
  @override
  late final GeneratedColumn<String> endDateOverride = GeneratedColumn<String>(
    'end_date_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteOverrideMeta = const VerificationMeta(
    'endMinuteOverride',
  );
  @override
  late final GeneratedColumn<int> endMinuteOverride = GeneratedColumn<int>(
    'end_minute_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    occurrenceKey,
    action,
    status,
    completedAt,
    titleOverride,
    noteOverride,
    planDateOverride,
    startMinuteOverride,
    endDateOverride,
    endMinuteOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occurrence_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<OccurrenceOverrideRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('occurrence_key')) {
      context.handle(
        _occurrenceKeyMeta,
        occurrenceKey.isAcceptableOrUnknown(
          data['occurrence_key']!,
          _occurrenceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceKeyMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('title_override')) {
      context.handle(
        _titleOverrideMeta,
        titleOverride.isAcceptableOrUnknown(
          data['title_override']!,
          _titleOverrideMeta,
        ),
      );
    }
    if (data.containsKey('note_override')) {
      context.handle(
        _noteOverrideMeta,
        noteOverride.isAcceptableOrUnknown(
          data['note_override']!,
          _noteOverrideMeta,
        ),
      );
    }
    if (data.containsKey('plan_date_override')) {
      context.handle(
        _planDateOverrideMeta,
        planDateOverride.isAcceptableOrUnknown(
          data['plan_date_override']!,
          _planDateOverrideMeta,
        ),
      );
    }
    if (data.containsKey('start_minute_override')) {
      context.handle(
        _startMinuteOverrideMeta,
        startMinuteOverride.isAcceptableOrUnknown(
          data['start_minute_override']!,
          _startMinuteOverrideMeta,
        ),
      );
    }
    if (data.containsKey('end_date_override')) {
      context.handle(
        _endDateOverrideMeta,
        endDateOverride.isAcceptableOrUnknown(
          data['end_date_override']!,
          _endDateOverrideMeta,
        ),
      );
    }
    if (data.containsKey('end_minute_override')) {
      context.handle(
        _endMinuteOverrideMeta,
        endMinuteOverride.isAcceptableOrUnknown(
          data['end_minute_override']!,
          _endMinuteOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OccurrenceOverrideRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OccurrenceOverrideRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      occurrenceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_key'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      titleOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_override'],
      ),
      noteOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_override'],
      ),
      planDateOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_date_override'],
      ),
      startMinuteOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute_override'],
      ),
      endDateOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date_override'],
      ),
      endMinuteOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute_override'],
      ),
    );
  }

  @override
  $OccurrenceOverridesTable createAlias(String alias) {
    return $OccurrenceOverridesTable(attachedDatabase, alias);
  }
}

class OccurrenceOverrideRow extends DataClass
    implements Insertable<OccurrenceOverrideRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String taskId;

  /// **原始**发生时刻的墙钟串（未被修改前的），唯一标识是哪一次。
  /// 格式见 §4.6：全天任务是纯日期，定时任务带 `THH:mm`。
  final String occurrenceKey;

  /// `skip` | `modify`。
  final String action;
  final String? status;
  final int? completedAt;

  /// NULL = 继承任务的对应字段。
  final String? titleOverride;
  final String? noteOverride;
  final String? planDateOverride;
  final int? startMinuteOverride;
  final String? endDateOverride;
  final int? endMinuteOverride;
  const OccurrenceOverrideRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.taskId,
    required this.occurrenceKey,
    required this.action,
    this.status,
    this.completedAt,
    this.titleOverride,
    this.noteOverride,
    this.planDateOverride,
    this.startMinuteOverride,
    this.endDateOverride,
    this.endMinuteOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['occurrence_key'] = Variable<String>(occurrenceKey);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || titleOverride != null) {
      map['title_override'] = Variable<String>(titleOverride);
    }
    if (!nullToAbsent || noteOverride != null) {
      map['note_override'] = Variable<String>(noteOverride);
    }
    if (!nullToAbsent || planDateOverride != null) {
      map['plan_date_override'] = Variable<String>(planDateOverride);
    }
    if (!nullToAbsent || startMinuteOverride != null) {
      map['start_minute_override'] = Variable<int>(startMinuteOverride);
    }
    if (!nullToAbsent || endDateOverride != null) {
      map['end_date_override'] = Variable<String>(endDateOverride);
    }
    if (!nullToAbsent || endMinuteOverride != null) {
      map['end_minute_override'] = Variable<int>(endMinuteOverride);
    }
    return map;
  }

  OccurrenceOverridesCompanion toCompanion(bool nullToAbsent) {
    return OccurrenceOverridesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      taskId: Value(taskId),
      occurrenceKey: Value(occurrenceKey),
      action: Value(action),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      titleOverride: titleOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(titleOverride),
      noteOverride: noteOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(noteOverride),
      planDateOverride: planDateOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(planDateOverride),
      startMinuteOverride: startMinuteOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinuteOverride),
      endDateOverride: endDateOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(endDateOverride),
      endMinuteOverride: endMinuteOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinuteOverride),
    );
  }

  factory OccurrenceOverrideRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OccurrenceOverrideRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      occurrenceKey: serializer.fromJson<String>(json['occurrenceKey']),
      action: serializer.fromJson<String>(json['action']),
      status: serializer.fromJson<String?>(json['status']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      titleOverride: serializer.fromJson<String?>(json['titleOverride']),
      noteOverride: serializer.fromJson<String?>(json['noteOverride']),
      planDateOverride: serializer.fromJson<String?>(json['planDateOverride']),
      startMinuteOverride: serializer.fromJson<int?>(
        json['startMinuteOverride'],
      ),
      endDateOverride: serializer.fromJson<String?>(json['endDateOverride']),
      endMinuteOverride: serializer.fromJson<int?>(json['endMinuteOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'occurrenceKey': serializer.toJson<String>(occurrenceKey),
      'action': serializer.toJson<String>(action),
      'status': serializer.toJson<String?>(status),
      'completedAt': serializer.toJson<int?>(completedAt),
      'titleOverride': serializer.toJson<String?>(titleOverride),
      'noteOverride': serializer.toJson<String?>(noteOverride),
      'planDateOverride': serializer.toJson<String?>(planDateOverride),
      'startMinuteOverride': serializer.toJson<int?>(startMinuteOverride),
      'endDateOverride': serializer.toJson<String?>(endDateOverride),
      'endMinuteOverride': serializer.toJson<int?>(endMinuteOverride),
    };
  }

  OccurrenceOverrideRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? taskId,
    String? occurrenceKey,
    String? action,
    Value<String?> status = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    Value<String?> titleOverride = const Value.absent(),
    Value<String?> noteOverride = const Value.absent(),
    Value<String?> planDateOverride = const Value.absent(),
    Value<int?> startMinuteOverride = const Value.absent(),
    Value<String?> endDateOverride = const Value.absent(),
    Value<int?> endMinuteOverride = const Value.absent(),
  }) => OccurrenceOverrideRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    occurrenceKey: occurrenceKey ?? this.occurrenceKey,
    action: action ?? this.action,
    status: status.present ? status.value : this.status,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    titleOverride: titleOverride.present
        ? titleOverride.value
        : this.titleOverride,
    noteOverride: noteOverride.present ? noteOverride.value : this.noteOverride,
    planDateOverride: planDateOverride.present
        ? planDateOverride.value
        : this.planDateOverride,
    startMinuteOverride: startMinuteOverride.present
        ? startMinuteOverride.value
        : this.startMinuteOverride,
    endDateOverride: endDateOverride.present
        ? endDateOverride.value
        : this.endDateOverride,
    endMinuteOverride: endMinuteOverride.present
        ? endMinuteOverride.value
        : this.endMinuteOverride,
  );
  OccurrenceOverrideRow copyWithCompanion(OccurrenceOverridesCompanion data) {
    return OccurrenceOverrideRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceKey: data.occurrenceKey.present
          ? data.occurrenceKey.value
          : this.occurrenceKey,
      action: data.action.present ? data.action.value : this.action,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      titleOverride: data.titleOverride.present
          ? data.titleOverride.value
          : this.titleOverride,
      noteOverride: data.noteOverride.present
          ? data.noteOverride.value
          : this.noteOverride,
      planDateOverride: data.planDateOverride.present
          ? data.planDateOverride.value
          : this.planDateOverride,
      startMinuteOverride: data.startMinuteOverride.present
          ? data.startMinuteOverride.value
          : this.startMinuteOverride,
      endDateOverride: data.endDateOverride.present
          ? data.endDateOverride.value
          : this.endDateOverride,
      endMinuteOverride: data.endMinuteOverride.present
          ? data.endMinuteOverride.value
          : this.endMinuteOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceOverrideRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('titleOverride: $titleOverride, ')
          ..write('noteOverride: $noteOverride, ')
          ..write('planDateOverride: $planDateOverride, ')
          ..write('startMinuteOverride: $startMinuteOverride, ')
          ..write('endDateOverride: $endDateOverride, ')
          ..write('endMinuteOverride: $endMinuteOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    occurrenceKey,
    action,
    status,
    completedAt,
    titleOverride,
    noteOverride,
    planDateOverride,
    startMinuteOverride,
    endDateOverride,
    endMinuteOverride,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OccurrenceOverrideRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.occurrenceKey == this.occurrenceKey &&
          other.action == this.action &&
          other.status == this.status &&
          other.completedAt == this.completedAt &&
          other.titleOverride == this.titleOverride &&
          other.noteOverride == this.noteOverride &&
          other.planDateOverride == this.planDateOverride &&
          other.startMinuteOverride == this.startMinuteOverride &&
          other.endDateOverride == this.endDateOverride &&
          other.endMinuteOverride == this.endMinuteOverride);
}

class OccurrenceOverridesCompanion
    extends UpdateCompanion<OccurrenceOverrideRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> occurrenceKey;
  final Value<String> action;
  final Value<String?> status;
  final Value<int?> completedAt;
  final Value<String?> titleOverride;
  final Value<String?> noteOverride;
  final Value<String?> planDateOverride;
  final Value<int?> startMinuteOverride;
  final Value<String?> endDateOverride;
  final Value<int?> endMinuteOverride;
  final Value<int> rowid;
  const OccurrenceOverridesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceKey = const Value.absent(),
    this.action = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.titleOverride = const Value.absent(),
    this.noteOverride = const Value.absent(),
    this.planDateOverride = const Value.absent(),
    this.startMinuteOverride = const Value.absent(),
    this.endDateOverride = const Value.absent(),
    this.endMinuteOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccurrenceOverridesCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String taskId,
    required String occurrenceKey,
    required String action,
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.titleOverride = const Value.absent(),
    this.noteOverride = const Value.absent(),
    this.planDateOverride = const Value.absent(),
    this.startMinuteOverride = const Value.absent(),
    this.endDateOverride = const Value.absent(),
    this.endMinuteOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       taskId = Value(taskId),
       occurrenceKey = Value(occurrenceKey),
       action = Value(action);
  static Insertable<OccurrenceOverrideRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? occurrenceKey,
    Expression<String>? action,
    Expression<String>? status,
    Expression<int>? completedAt,
    Expression<String>? titleOverride,
    Expression<String>? noteOverride,
    Expression<String>? planDateOverride,
    Expression<int>? startMinuteOverride,
    Expression<String>? endDateOverride,
    Expression<int>? endMinuteOverride,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceKey != null) 'occurrence_key': occurrenceKey,
      if (action != null) 'action': action,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (titleOverride != null) 'title_override': titleOverride,
      if (noteOverride != null) 'note_override': noteOverride,
      if (planDateOverride != null) 'plan_date_override': planDateOverride,
      if (startMinuteOverride != null)
        'start_minute_override': startMinuteOverride,
      if (endDateOverride != null) 'end_date_override': endDateOverride,
      if (endMinuteOverride != null) 'end_minute_override': endMinuteOverride,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccurrenceOverridesCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? occurrenceKey,
    Value<String>? action,
    Value<String?>? status,
    Value<int?>? completedAt,
    Value<String?>? titleOverride,
    Value<String?>? noteOverride,
    Value<String?>? planDateOverride,
    Value<int?>? startMinuteOverride,
    Value<String?>? endDateOverride,
    Value<int?>? endMinuteOverride,
    Value<int>? rowid,
  }) {
    return OccurrenceOverridesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      action: action ?? this.action,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      titleOverride: titleOverride ?? this.titleOverride,
      noteOverride: noteOverride ?? this.noteOverride,
      planDateOverride: planDateOverride ?? this.planDateOverride,
      startMinuteOverride: startMinuteOverride ?? this.startMinuteOverride,
      endDateOverride: endDateOverride ?? this.endDateOverride,
      endMinuteOverride: endMinuteOverride ?? this.endMinuteOverride,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceKey.present) {
      map['occurrence_key'] = Variable<String>(occurrenceKey.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (titleOverride.present) {
      map['title_override'] = Variable<String>(titleOverride.value);
    }
    if (noteOverride.present) {
      map['note_override'] = Variable<String>(noteOverride.value);
    }
    if (planDateOverride.present) {
      map['plan_date_override'] = Variable<String>(planDateOverride.value);
    }
    if (startMinuteOverride.present) {
      map['start_minute_override'] = Variable<int>(startMinuteOverride.value);
    }
    if (endDateOverride.present) {
      map['end_date_override'] = Variable<String>(endDateOverride.value);
    }
    if (endMinuteOverride.present) {
      map['end_minute_override'] = Variable<int>(endMinuteOverride.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccurrenceOverridesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('titleOverride: $titleOverride, ')
          ..write('noteOverride: $noteOverride, ')
          ..write('planDateOverride: $planDateOverride, ')
          ..write('startMinuteOverride: $startMinuteOverride, ')
          ..write('endDateOverride: $endDateOverride, ')
          ..write('endMinuteOverride: $endMinuteOverride, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StageOccurrenceStatesTable extends StageOccurrenceStates
    with TableInfo<$StageOccurrenceStatesTable, StageOccurrenceStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StageOccurrenceStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stageIdMeta = const VerificationMeta(
    'stageId',
  );
  @override
  late final GeneratedColumn<String> stageId = GeneratedColumn<String>(
    'stage_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _occurrenceKeyMeta = const VerificationMeta(
    'occurrenceKey',
  );
  @override
  late final GeneratedColumn<String> occurrenceKey = GeneratedColumn<String>(
    'occurrence_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    stageId,
    occurrenceKey,
    status,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stage_occurrence_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<StageOccurrenceStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('stage_id')) {
      context.handle(
        _stageIdMeta,
        stageId.isAcceptableOrUnknown(data['stage_id']!, _stageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stageIdMeta);
    }
    if (data.containsKey('occurrence_key')) {
      context.handle(
        _occurrenceKeyMeta,
        occurrenceKey.isAcceptableOrUnknown(
          data['occurrence_key']!,
          _occurrenceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StageOccurrenceStateRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageOccurrenceStateRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      stageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_id'],
      )!,
      occurrenceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $StageOccurrenceStatesTable createAlias(String alias) {
    return $StageOccurrenceStatesTable(attachedDatabase, alias);
  }
}

class StageOccurrenceStateRow extends DataClass
    implements Insertable<StageOccurrenceStateRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String taskId;
  final String stageId;
  final String occurrenceKey;
  final String status;
  final int? completedAt;
  const StageOccurrenceStateRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.taskId,
    required this.stageId,
    required this.occurrenceKey,
    required this.status,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['stage_id'] = Variable<String>(stageId);
    map['occurrence_key'] = Variable<String>(occurrenceKey);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  StageOccurrenceStatesCompanion toCompanion(bool nullToAbsent) {
    return StageOccurrenceStatesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      taskId: Value(taskId),
      stageId: Value(stageId),
      occurrenceKey: Value(occurrenceKey),
      status: Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory StageOccurrenceStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StageOccurrenceStateRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      stageId: serializer.fromJson<String>(json['stageId']),
      occurrenceKey: serializer.fromJson<String>(json['occurrenceKey']),
      status: serializer.fromJson<String>(json['status']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'stageId': serializer.toJson<String>(stageId),
      'occurrenceKey': serializer.toJson<String>(occurrenceKey),
      'status': serializer.toJson<String>(status),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  StageOccurrenceStateRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? taskId,
    String? stageId,
    String? occurrenceKey,
    String? status,
    Value<int?> completedAt = const Value.absent(),
  }) => StageOccurrenceStateRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    stageId: stageId ?? this.stageId,
    occurrenceKey: occurrenceKey ?? this.occurrenceKey,
    status: status ?? this.status,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  StageOccurrenceStateRow copyWithCompanion(
    StageOccurrenceStatesCompanion data,
  ) {
    return StageOccurrenceStateRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      stageId: data.stageId.present ? data.stageId.value : this.stageId,
      occurrenceKey: data.occurrenceKey.present
          ? data.occurrenceKey.value
          : this.occurrenceKey,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageOccurrenceStateRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('stageId: $stageId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    stageId,
    occurrenceKey,
    status,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageOccurrenceStateRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.stageId == this.stageId &&
          other.occurrenceKey == this.occurrenceKey &&
          other.status == this.status &&
          other.completedAt == this.completedAt);
}

class StageOccurrenceStatesCompanion
    extends UpdateCompanion<StageOccurrenceStateRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> stageId;
  final Value<String> occurrenceKey;
  final Value<String> status;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const StageOccurrenceStatesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.stageId = const Value.absent(),
    this.occurrenceKey = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StageOccurrenceStatesCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String taskId,
    required String stageId,
    required String occurrenceKey,
    required String status,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       taskId = Value(taskId),
       stageId = Value(stageId),
       occurrenceKey = Value(occurrenceKey),
       status = Value(status);
  static Insertable<StageOccurrenceStateRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? stageId,
    Expression<String>? occurrenceKey,
    Expression<String>? status,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (stageId != null) 'stage_id': stageId,
      if (occurrenceKey != null) 'occurrence_key': occurrenceKey,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StageOccurrenceStatesCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? stageId,
    Value<String>? occurrenceKey,
    Value<String>? status,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return StageOccurrenceStatesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      stageId: stageId ?? this.stageId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (stageId.present) {
      map['stage_id'] = Variable<String>(stageId.value);
    }
    if (occurrenceKey.present) {
      map['occurrence_key'] = Variable<String>(occurrenceKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StageOccurrenceStatesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('stageId: $stageId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMinutesMeta = const VerificationMeta(
    'offsetMinutes',
  );
  @override
  late final GeneratedColumn<int> offsetMinutes = GeneratedColumn<int>(
    'offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _absoluteDateMeta = const VerificationMeta(
    'absoluteDate',
  );
  @override
  late final GeneratedColumn<String> absoluteDate = GeneratedColumn<String>(
    'absolute_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _absoluteMinuteMeta = const VerificationMeta(
    'absoluteMinute',
  );
  @override
  late final GeneratedColumn<int> absoluteMinute = GeneratedColumn<int>(
    'absolute_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    kind,
    offsetMinutes,
    absoluteDate,
    absoluteMinute,
    isEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('offset_minutes')) {
      context.handle(
        _offsetMinutesMeta,
        offsetMinutes.isAcceptableOrUnknown(
          data['offset_minutes']!,
          _offsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('absolute_date')) {
      context.handle(
        _absoluteDateMeta,
        absoluteDate.isAcceptableOrUnknown(
          data['absolute_date']!,
          _absoluteDateMeta,
        ),
      );
    }
    if (data.containsKey('absolute_minute')) {
      context.handle(
        _absoluteMinuteMeta,
        absoluteMinute.isAcceptableOrUnknown(
          data['absolute_minute']!,
          _absoluteMinuteMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      offsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_minutes'],
      ),
      absoluteDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}absolute_date'],
      ),
      absoluteMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}absolute_minute'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String taskId;

  /// `relativeToStart` | `relativeToEnd` | `absolute`。
  final String kind;

  /// 负数 = 提前；[kind] 为相对时必填。
  final int? offsetMinutes;

  /// `kind=absolute` 时的墙钟日期。
  final String? absoluteDate;
  final int? absoluteMinute;
  final bool isEnabled;
  const ReminderRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.taskId,
    required this.kind,
    this.offsetMinutes,
    this.absoluteDate,
    this.absoluteMinute,
    required this.isEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || offsetMinutes != null) {
      map['offset_minutes'] = Variable<int>(offsetMinutes);
    }
    if (!nullToAbsent || absoluteDate != null) {
      map['absolute_date'] = Variable<String>(absoluteDate);
    }
    if (!nullToAbsent || absoluteMinute != null) {
      map['absolute_minute'] = Variable<int>(absoluteMinute);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      taskId: Value(taskId),
      kind: Value(kind),
      offsetMinutes: offsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(offsetMinutes),
      absoluteDate: absoluteDate == null && nullToAbsent
          ? const Value.absent()
          : Value(absoluteDate),
      absoluteMinute: absoluteMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(absoluteMinute),
      isEnabled: Value(isEnabled),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      kind: serializer.fromJson<String>(json['kind']),
      offsetMinutes: serializer.fromJson<int?>(json['offsetMinutes']),
      absoluteDate: serializer.fromJson<String?>(json['absoluteDate']),
      absoluteMinute: serializer.fromJson<int?>(json['absoluteMinute']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'kind': serializer.toJson<String>(kind),
      'offsetMinutes': serializer.toJson<int?>(offsetMinutes),
      'absoluteDate': serializer.toJson<String?>(absoluteDate),
      'absoluteMinute': serializer.toJson<int?>(absoluteMinute),
      'isEnabled': serializer.toJson<bool>(isEnabled),
    };
  }

  ReminderRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? taskId,
    String? kind,
    Value<int?> offsetMinutes = const Value.absent(),
    Value<String?> absoluteDate = const Value.absent(),
    Value<int?> absoluteMinute = const Value.absent(),
    bool? isEnabled,
  }) => ReminderRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    kind: kind ?? this.kind,
    offsetMinutes: offsetMinutes.present
        ? offsetMinutes.value
        : this.offsetMinutes,
    absoluteDate: absoluteDate.present ? absoluteDate.value : this.absoluteDate,
    absoluteMinute: absoluteMinute.present
        ? absoluteMinute.value
        : this.absoluteMinute,
    isEnabled: isEnabled ?? this.isEnabled,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      kind: data.kind.present ? data.kind.value : this.kind,
      offsetMinutes: data.offsetMinutes.present
          ? data.offsetMinutes.value
          : this.offsetMinutes,
      absoluteDate: data.absoluteDate.present
          ? data.absoluteDate.value
          : this.absoluteDate,
      absoluteMinute: data.absoluteMinute.present
          ? data.absoluteMinute.value
          : this.absoluteMinute,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('absoluteDate: $absoluteDate, ')
          ..write('absoluteMinute: $absoluteMinute, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    taskId,
    kind,
    offsetMinutes,
    absoluteDate,
    absoluteMinute,
    isEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.kind == this.kind &&
          other.offsetMinutes == this.offsetMinutes &&
          other.absoluteDate == this.absoluteDate &&
          other.absoluteMinute == this.absoluteMinute &&
          other.isEnabled == this.isEnabled);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> kind;
  final Value<int?> offsetMinutes;
  final Value<String?> absoluteDate;
  final Value<int?> absoluteMinute;
  final Value<bool> isEnabled;
  final Value<int> rowid;
  const RemindersCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.kind = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.absoluteDate = const Value.absent(),
    this.absoluteMinute = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String taskId,
    required String kind,
    this.offsetMinutes = const Value.absent(),
    this.absoluteDate = const Value.absent(),
    this.absoluteMinute = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       taskId = Value(taskId),
       kind = Value(kind);
  static Insertable<ReminderRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? kind,
    Expression<int>? offsetMinutes,
    Expression<String>? absoluteDate,
    Expression<int>? absoluteMinute,
    Expression<bool>? isEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (kind != null) 'kind': kind,
      if (offsetMinutes != null) 'offset_minutes': offsetMinutes,
      if (absoluteDate != null) 'absolute_date': absoluteDate,
      if (absoluteMinute != null) 'absolute_minute': absoluteMinute,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? kind,
    Value<int?>? offsetMinutes,
    Value<String?>? absoluteDate,
    Value<int?>? absoluteMinute,
    Value<bool>? isEnabled,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      absoluteDate: absoluteDate ?? this.absoluteDate,
      absoluteMinute: absoluteMinute ?? this.absoluteMinute,
      isEnabled: isEnabled ?? this.isEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (offsetMinutes.present) {
      map['offset_minutes'] = Variable<int>(offsetMinutes.value);
    }
    if (absoluteDate.present) {
      map['absolute_date'] = Variable<String>(absoluteDate.value);
    }
    if (absoluteMinute.present) {
      map['absolute_minute'] = Variable<int>(absoluteMinute.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('kind: $kind, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('absoluteDate: $absoluteDate, ')
          ..write('absoluteMinute: $absoluteMinute, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    name,
    colorArgb,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String id;
  final String name;
  final int colorArgb;
  const TagRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.id,
    required this.name,
    required this.colorArgb,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_argb'] = Variable<int>(colorArgb);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      id: Value(id),
      name: Value(name),
      colorArgb: Value(colorArgb),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorArgb': serializer.toJson<int>(colorArgb),
    };
  }

  TagRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? id,
    String? name,
    int? colorArgb,
  }) => TagRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    id,
    name,
    colorArgb,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorArgb == this.colorArgb);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorArgb;
  final Value<int> rowid;
  const TagsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String id,
    required String name,
    required int colorArgb,
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       id = Value(id),
       name = Value(name),
       colorArgb = Value(colorArgb);
  static Insertable<TagRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorArgb,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorArgb,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      id: id ?? this.id,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagsTable extends TaskTags
    with TableInfo<$TaskTagsTable, TaskTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    taskId,
    tagId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TaskTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTagRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TaskTagsTable createAlias(String alias) {
    return $TaskTagsTable(attachedDatabase, alias);
  }
}

class TaskTagRow extends DataClass implements Insertable<TaskTagRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String taskId;
  final String tagId;
  const TaskTagRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.taskId,
    required this.tagId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      taskId: Value(taskId),
      tagId: Value(tagId),
    );
  }

  factory TaskTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTagRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TaskTagRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? taskId,
    String? tagId,
  }) => TaskTagRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    taskId: taskId ?? this.taskId,
    tagId: tagId ?? this.tagId,
  );
  TaskTagRow copyWithCompanion(TaskTagsCompanion data) {
    return TaskTagRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    taskId,
    tagId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTagRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTagRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TaskTagRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastWriterIdMeta = const VerificationMeta(
    'lastWriterId',
  );
  @override
  late final GeneratedColumn<String> lastWriterId = GeneratedColumn<String>(
    'last_writer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteVersionMeta = const VerificationMeta(
    'remoteVersion',
  );
  @override
  late final GeneratedColumn<String> remoteVersion = GeneratedColumn<String>(
    'remote_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    key,
    valueJson,
    scope,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_writer_id')) {
      context.handle(
        _lastWriterIdMeta,
        lastWriterId.isAcceptableOrUnknown(
          data['last_writer_id']!,
          _lastWriterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWriterIdMeta);
    }
    if (data.containsKey('remote_version')) {
      context.handle(
        _remoteVersionMeta,
        remoteVersion.isAcceptableOrUnknown(
          data['remote_version']!,
          _remoteVersionMeta,
        ),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastWriterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_writer_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_version'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  /// 创建时刻，Instant ms。**创建后不再变**。
  final int createdAt;

  /// 最后一次本地写入时刻，Instant ms。
  final int updatedAt;

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  final int? deletedAt;

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  final int revision;

  /// 写入方设备 ID。
  final String lastWriterId;

  /// 服务端版本标记。V1 恒为 NULL。
  final String? remoteVersion;
  final String key;
  final String valueJson;

  /// `global`（参与同步）| `device`（不同步）。
  ///
  /// 用列而不是拆两张表：注册表按 key 查询时不必先知道 scope。
  final String scope;
  const SettingRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastWriterId,
    this.remoteVersion,
    required this.key,
    required this.valueJson,
    required this.scope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_writer_id'] = Variable<String>(lastWriterId);
    if (!nullToAbsent || remoteVersion != null) {
      map['remote_version'] = Variable<String>(remoteVersion);
    }
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['scope'] = Variable<String>(scope);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastWriterId: Value(lastWriterId),
      remoteVersion: remoteVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteVersion),
      key: Value(key),
      valueJson: Value(valueJson),
      scope: Value(scope),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastWriterId: serializer.fromJson<String>(json['lastWriterId']),
      remoteVersion: serializer.fromJson<String?>(json['remoteVersion']),
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      scope: serializer.fromJson<String>(json['scope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastWriterId': serializer.toJson<String>(lastWriterId),
      'remoteVersion': serializer.toJson<String?>(remoteVersion),
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'scope': serializer.toJson<String>(scope),
    };
  }

  SettingRow copyWith({
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? revision,
    String? lastWriterId,
    Value<String?> remoteVersion = const Value.absent(),
    String? key,
    String? valueJson,
    String? scope,
  }) => SettingRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastWriterId: lastWriterId ?? this.lastWriterId,
    remoteVersion: remoteVersion.present
        ? remoteVersion.value
        : this.remoteVersion,
    key: key ?? this.key,
    valueJson: valueJson ?? this.valueJson,
    scope: scope ?? this.scope,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastWriterId: data.lastWriterId.present
          ? data.lastWriterId.value
          : this.lastWriterId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastWriterId,
    remoteVersion,
    key,
    valueJson,
    scope,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastWriterId == this.lastWriterId &&
          other.remoteVersion == this.remoteVersion &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.scope == this.scope);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> revision;
  final Value<String> lastWriterId;
  final Value<String?> remoteVersion;
  final Value<String> key;
  final Value<String> valueJson;
  final Value<String> scope;
  final Value<int> rowid;
  const SettingsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastWriterId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.scope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    required String lastWriterId,
    this.remoteVersion = const Value.absent(),
    required String key,
    required String valueJson,
    required String scope,
    this.rowid = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       lastWriterId = Value(lastWriterId),
       key = Value(key),
       valueJson = Value(valueJson),
       scope = Value(scope);
  static Insertable<SettingRow> custom({
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastWriterId,
    Expression<String>? remoteVersion,
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<String>? scope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastWriterId != null) 'last_writer_id': lastWriterId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (scope != null) 'scope': scope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastWriterId,
    Value<String?>? remoteVersion,
    Value<String>? key,
    Value<String>? valueJson,
    Value<String>? scope,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastWriterId: lastWriterId ?? this.lastWriterId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      scope: scope ?? this.scope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastWriterId.present) {
      map['last_writer_id'] = Variable<String>(lastWriterId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<String>(remoteVersion.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastWriterId: $lastWriterId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('scope: $scope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledNotificationsTable extends ScheduledNotifications
    with TableInfo<$ScheduledNotificationsTable, ScheduledNotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _osNotificationIdMeta = const VerificationMeta(
    'osNotificationId',
  );
  @override
  late final GeneratedColumn<int> osNotificationId = GeneratedColumn<int>(
    'os_notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceKeyMeta = const VerificationMeta(
    'occurrenceKey',
  );
  @override
  late final GeneratedColumn<String> occurrenceKey = GeneratedColumn<String>(
    'occurrence_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fireAtInstantMeta = const VerificationMeta(
    'fireAtInstant',
  );
  @override
  late final GeneratedColumn<int> fireAtInstant = GeneratedColumn<int>(
    'fire_at_instant',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    osNotificationId,
    reminderId,
    taskId,
    occurrenceKey,
    fireAtInstant,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledNotificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('os_notification_id')) {
      context.handle(
        _osNotificationIdMeta,
        osNotificationId.isAcceptableOrUnknown(
          data['os_notification_id']!,
          _osNotificationIdMeta,
        ),
      );
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('occurrence_key')) {
      context.handle(
        _occurrenceKeyMeta,
        occurrenceKey.isAcceptableOrUnknown(
          data['occurrence_key']!,
          _occurrenceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceKeyMeta);
    }
    if (data.containsKey('fire_at_instant')) {
      context.handle(
        _fireAtInstantMeta,
        fireAtInstant.isAcceptableOrUnknown(
          data['fire_at_instant']!,
          _fireAtInstantMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fireAtInstantMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {osNotificationId};
  @override
  ScheduledNotificationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledNotificationRow(
      osNotificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}os_notification_id'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      occurrenceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_key'],
      )!,
      fireAtInstant: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fire_at_instant'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $ScheduledNotificationsTable createAlias(String alias) {
    return $ScheduledNotificationsTable(attachedDatabase, alias);
  }
}

class ScheduledNotificationRow extends DataClass
    implements Insertable<ScheduledNotificationRow> {
  /// 传给系统的 ID。
  final int osNotificationId;
  final String reminderId;
  final String taskId;
  final String occurrenceKey;

  /// UTC ms。
  final int fireAtInstant;

  /// `scheduled` | `fired` | `cancelled`。
  final String state;
  const ScheduledNotificationRow({
    required this.osNotificationId,
    required this.reminderId,
    required this.taskId,
    required this.occurrenceKey,
    required this.fireAtInstant,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['os_notification_id'] = Variable<int>(osNotificationId);
    map['reminder_id'] = Variable<String>(reminderId);
    map['task_id'] = Variable<String>(taskId);
    map['occurrence_key'] = Variable<String>(occurrenceKey);
    map['fire_at_instant'] = Variable<int>(fireAtInstant);
    map['state'] = Variable<String>(state);
    return map;
  }

  ScheduledNotificationsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledNotificationsCompanion(
      osNotificationId: Value(osNotificationId),
      reminderId: Value(reminderId),
      taskId: Value(taskId),
      occurrenceKey: Value(occurrenceKey),
      fireAtInstant: Value(fireAtInstant),
      state: Value(state),
    );
  }

  factory ScheduledNotificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledNotificationRow(
      osNotificationId: serializer.fromJson<int>(json['osNotificationId']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      occurrenceKey: serializer.fromJson<String>(json['occurrenceKey']),
      fireAtInstant: serializer.fromJson<int>(json['fireAtInstant']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'osNotificationId': serializer.toJson<int>(osNotificationId),
      'reminderId': serializer.toJson<String>(reminderId),
      'taskId': serializer.toJson<String>(taskId),
      'occurrenceKey': serializer.toJson<String>(occurrenceKey),
      'fireAtInstant': serializer.toJson<int>(fireAtInstant),
      'state': serializer.toJson<String>(state),
    };
  }

  ScheduledNotificationRow copyWith({
    int? osNotificationId,
    String? reminderId,
    String? taskId,
    String? occurrenceKey,
    int? fireAtInstant,
    String? state,
  }) => ScheduledNotificationRow(
    osNotificationId: osNotificationId ?? this.osNotificationId,
    reminderId: reminderId ?? this.reminderId,
    taskId: taskId ?? this.taskId,
    occurrenceKey: occurrenceKey ?? this.occurrenceKey,
    fireAtInstant: fireAtInstant ?? this.fireAtInstant,
    state: state ?? this.state,
  );
  ScheduledNotificationRow copyWithCompanion(
    ScheduledNotificationsCompanion data,
  ) {
    return ScheduledNotificationRow(
      osNotificationId: data.osNotificationId.present
          ? data.osNotificationId.value
          : this.osNotificationId,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      occurrenceKey: data.occurrenceKey.present
          ? data.occurrenceKey.value
          : this.occurrenceKey,
      fireAtInstant: data.fireAtInstant.present
          ? data.fireAtInstant.value
          : this.fireAtInstant,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotificationRow(')
          ..write('osNotificationId: $osNotificationId, ')
          ..write('reminderId: $reminderId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('fireAtInstant: $fireAtInstant, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    osNotificationId,
    reminderId,
    taskId,
    occurrenceKey,
    fireAtInstant,
    state,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledNotificationRow &&
          other.osNotificationId == this.osNotificationId &&
          other.reminderId == this.reminderId &&
          other.taskId == this.taskId &&
          other.occurrenceKey == this.occurrenceKey &&
          other.fireAtInstant == this.fireAtInstant &&
          other.state == this.state);
}

class ScheduledNotificationsCompanion
    extends UpdateCompanion<ScheduledNotificationRow> {
  final Value<int> osNotificationId;
  final Value<String> reminderId;
  final Value<String> taskId;
  final Value<String> occurrenceKey;
  final Value<int> fireAtInstant;
  final Value<String> state;
  const ScheduledNotificationsCompanion({
    this.osNotificationId = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.occurrenceKey = const Value.absent(),
    this.fireAtInstant = const Value.absent(),
    this.state = const Value.absent(),
  });
  ScheduledNotificationsCompanion.insert({
    this.osNotificationId = const Value.absent(),
    required String reminderId,
    required String taskId,
    required String occurrenceKey,
    required int fireAtInstant,
    required String state,
  }) : reminderId = Value(reminderId),
       taskId = Value(taskId),
       occurrenceKey = Value(occurrenceKey),
       fireAtInstant = Value(fireAtInstant),
       state = Value(state);
  static Insertable<ScheduledNotificationRow> custom({
    Expression<int>? osNotificationId,
    Expression<String>? reminderId,
    Expression<String>? taskId,
    Expression<String>? occurrenceKey,
    Expression<int>? fireAtInstant,
    Expression<String>? state,
  }) {
    return RawValuesInsertable({
      if (osNotificationId != null) 'os_notification_id': osNotificationId,
      if (reminderId != null) 'reminder_id': reminderId,
      if (taskId != null) 'task_id': taskId,
      if (occurrenceKey != null) 'occurrence_key': occurrenceKey,
      if (fireAtInstant != null) 'fire_at_instant': fireAtInstant,
      if (state != null) 'state': state,
    });
  }

  ScheduledNotificationsCompanion copyWith({
    Value<int>? osNotificationId,
    Value<String>? reminderId,
    Value<String>? taskId,
    Value<String>? occurrenceKey,
    Value<int>? fireAtInstant,
    Value<String>? state,
  }) {
    return ScheduledNotificationsCompanion(
      osNotificationId: osNotificationId ?? this.osNotificationId,
      reminderId: reminderId ?? this.reminderId,
      taskId: taskId ?? this.taskId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      fireAtInstant: fireAtInstant ?? this.fireAtInstant,
      state: state ?? this.state,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (osNotificationId.present) {
      map['os_notification_id'] = Variable<int>(osNotificationId.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (occurrenceKey.present) {
      map['occurrence_key'] = Variable<String>(occurrenceKey.value);
    }
    if (fireAtInstant.present) {
      map['fire_at_instant'] = Variable<int>(fireAtInstant.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotificationsCompanion(')
          ..write('osNotificationId: $osNotificationId, ')
          ..write('reminderId: $reminderId, ')
          ..write('taskId: $taskId, ')
          ..write('occurrenceKey: $occurrenceKey, ')
          ..write('fireAtInstant: $fireAtInstant, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }
}

class $ChangeLogTable extends ChangeLog
    with TableInfo<$ChangeLogTable, ChangeLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangeLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    entityType,
    entityId,
    op,
    payloadJson,
    occurredAt,
    deviceId,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  ChangeLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeLogRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $ChangeLogTable createAlias(String alias) {
    return $ChangeLogTable(attachedDatabase, alias);
  }
}

class ChangeLogRow extends DataClass implements Insertable<ChangeLogRow> {
  /// 本地单调序号。回放顺序即写入顺序。
  final int seq;

  /// `task` / `stage` / …
  final String entityType;
  final String entityId;

  /// `upsert` | `delete`。
  final String op;

  /// upsert 时为该行的完整 JSON。
  final String? payloadJson;

  /// Instant ms。
  final int occurredAt;
  final String deviceId;

  /// V3 用；V1 恒为 NULL。
  final int? syncedAt;
  const ChangeLogRow({
    required this.seq,
    required this.entityType,
    required this.entityId,
    required this.op,
    this.payloadJson,
    required this.occurredAt,
    required this.deviceId,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    return map;
  }

  ChangeLogCompanion toCompanion(bool nullToAbsent) {
    return ChangeLogCompanion(
      seq: Value(seq),
      entityType: Value(entityType),
      entityId: Value(entityId),
      op: Value(op),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      occurredAt: Value(occurredAt),
      deviceId: Value(deviceId),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ChangeLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeLogRow(
      seq: serializer.fromJson<int>(json['seq']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'syncedAt': serializer.toJson<int?>(syncedAt),
    };
  }

  ChangeLogRow copyWith({
    int? seq,
    String? entityType,
    String? entityId,
    String? op,
    Value<String?> payloadJson = const Value.absent(),
    int? occurredAt,
    String? deviceId,
    Value<int?> syncedAt = const Value.absent(),
  }) => ChangeLogRow(
    seq: seq ?? this.seq,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    occurredAt: occurredAt ?? this.occurredAt,
    deviceId: deviceId ?? this.deviceId,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  ChangeLogRow copyWithCompanion(ChangeLogCompanion data) {
    return ChangeLogRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogRow(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    entityType,
    entityId,
    op,
    payloadJson,
    occurredAt,
    deviceId,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeLogRow &&
          other.seq == this.seq &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.payloadJson == this.payloadJson &&
          other.occurredAt == this.occurredAt &&
          other.deviceId == this.deviceId &&
          other.syncedAt == this.syncedAt);
}

class ChangeLogCompanion extends UpdateCompanion<ChangeLogRow> {
  final Value<int> seq;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> op;
  final Value<String?> payloadJson;
  final Value<int> occurredAt;
  final Value<String> deviceId;
  final Value<int?> syncedAt;
  const ChangeLogCompanion({
    this.seq = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  ChangeLogCompanion.insert({
    this.seq = const Value.absent(),
    required String entityType,
    required String entityId,
    required String op,
    this.payloadJson = const Value.absent(),
    required int occurredAt,
    required String deviceId,
    this.syncedAt = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       op = Value(op),
       occurredAt = Value(occurredAt),
       deviceId = Value(deviceId);
  static Insertable<ChangeLogRow> custom({
    Expression<int>? seq,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<String>? payloadJson,
    Expression<int>? occurredAt,
    Expression<String>? deviceId,
    Expression<int>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (deviceId != null) 'device_id': deviceId,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  ChangeLogCompanion copyWith({
    Value<int>? seq,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? op,
    Value<String?>? payloadJson,
    Value<int>? occurredAt,
    Value<String>? deviceId,
    Value<int?>? syncedAt,
  }) {
    return ChangeLogCompanion(
      seq: seq ?? this.seq,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      payloadJson: payloadJson ?? this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceId: deviceId ?? this.deviceId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogCompanion(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $StagesTable stages = $StagesTable(this);
  late final $ChecklistItemsTable checklistItems = $ChecklistItemsTable(this);
  late final $OccurrenceOverridesTable occurrenceOverrides =
      $OccurrenceOverridesTable(this);
  late final $StageOccurrenceStatesTable stageOccurrenceStates =
      $StageOccurrenceStatesTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ScheduledNotificationsTable scheduledNotifications =
      $ScheduledNotificationsTable(this);
  late final $ChangeLogTable changeLog = $ChangeLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    tasks,
    stages,
    checklistItems,
    occurrenceOverrides,
    stageOccurrenceStates,
    reminders,
    tags,
    taskTags,
    settings,
    scheduledNotifications,
    changeLog,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checklist_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('occurrence_overrides', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stage_occurrence_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stage_occurrence_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String id,
  required String name,
  required int colorArgb,
  required String icon,
  required int orderIndex,
  Value<bool> isSystemDefault,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> id,
  Value<String> name,
  Value<int> colorArgb,
  Value<String> icon,
  Value<int> orderIndex,
  Value<bool> isSystemDefault,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'categories__id__tasks__category_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystemDefault => $composableBuilder(
    column: $table.isSystemDefault,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystemDefault => $composableBuilder(
    column: $table.isSystemDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSystemDefault => $composableBuilder(
    column: $table.isSystemDefault,
    builder: (column) => column,
  );

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<bool> isSystemDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                name: name,
                colorArgb: colorArgb,
                icon: icon,
                orderIndex: orderIndex,
                isSystemDefault: isSystemDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String name,
                required int colorArgb,
                required String icon,
                required int orderIndex,
                Value<bool> isSystemDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                name: name,
                colorArgb: colorArgb,
                icon: icon,
                orderIndex: orderIndex,
                isSystemDefault: isSystemDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<
                      CategoryRow,
                      $CategoriesTable,
                      TaskRow
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String id,
  required String title,
  Value<String?> note,
  required String kind,
  Value<String?> categoryId,
  Value<int> priority,
  Value<String> status,
  Value<String?> statusBeforeArchive,
  Value<bool> isAllDay,
  Value<String?> planDate,
  Value<int?> startMinute,
  Value<String?> endDate,
  Value<int?> endMinute,
  required String timeZoneId,
  Value<String?> recurrenceRule,
  Value<String?> recurrenceExDates,
  Value<String?> splitFromTaskId,
  Value<int?> colorArgb,
  Value<String?> icon,
  Value<double> sortOrder,
  Value<int?> completedAt,
  Value<int?> archivedAt,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> id,
  Value<String> title,
  Value<String?> note,
  Value<String> kind,
  Value<String?> categoryId,
  Value<int> priority,
  Value<String> status,
  Value<String?> statusBeforeArchive,
  Value<bool> isAllDay,
  Value<String?> planDate,
  Value<int?> startMinute,
  Value<String?> endDate,
  Value<int?> endMinute,
  Value<String> timeZoneId,
  Value<String?> recurrenceRule,
  Value<String?> recurrenceExDates,
  Value<String?> splitFromTaskId,
  Value<int?> colorArgb,
  Value<String?> icon,
  Value<double> sortOrder,
  Value<int?> completedAt,
  Value<int?> archivedAt,
  Value<int> rowid,
});

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('tasks__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StagesTable, List<StageRow>> _stagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.stages,
    aliasName: 'tasks__id__stages__task_id',
  );

  $$StagesTableProcessedTableManager get stagesRefs {
    final manager = $$StagesTableTableManager(
      $_db,
      $_db.stages,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChecklistItemsTable, List<ChecklistItemRow>>
  _checklistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checklistItems,
    aliasName: 'tasks__id__checklist_items__task_id',
  );

  $$ChecklistItemsTableProcessedTableManager get checklistItemsRefs {
    final manager = $$ChecklistItemsTableTableManager(
      $_db,
      $_db.checklistItems,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_checklistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $OccurrenceOverridesTable,
    List<OccurrenceOverrideRow>
  >
  _occurrenceOverridesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.occurrenceOverrides,
        aliasName: 'tasks__id__occurrence_overrides__task_id',
      );

  $$OccurrenceOverridesTableProcessedTableManager get occurrenceOverridesRefs {
    final manager = $$OccurrenceOverridesTableTableManager(
      $_db,
      $_db.occurrenceOverrides,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _occurrenceOverridesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $StageOccurrenceStatesTable,
    List<StageOccurrenceStateRow>
  >
  _stageOccurrenceStatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stageOccurrenceStates,
        aliasName: 'tasks__id__stage_occurrence_states__task_id',
      );

  $$StageOccurrenceStatesTableProcessedTableManager
  get stageOccurrenceStatesRefs {
    final manager = $$StageOccurrenceStatesTableTableManager(
      $_db,
      $_db.stageOccurrenceStates,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stageOccurrenceStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'tasks__id__reminders__task_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTagRow>>
  _taskTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: 'tasks__id__task_tags__task_id',
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusBeforeArchive => $composableBuilder(
    column: $table.statusBeforeArchive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceExDates => $composableBuilder(
    column: $table.recurrenceExDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get splitFromTaskId => $composableBuilder(
    column: $table.splitFromTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stagesRefs(
    Expression<bool> Function($$StagesTableFilterComposer f) f,
  ) {
    final $$StagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stages,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StagesTableFilterComposer(
            $db: $db,
            $table: $db.stages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> checklistItemsRefs(
    Expression<bool> Function($$ChecklistItemsTableFilterComposer f) f,
  ) {
    final $$ChecklistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableFilterComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> occurrenceOverridesRefs(
    Expression<bool> Function($$OccurrenceOverridesTableFilterComposer f) f,
  ) {
    final $$OccurrenceOverridesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.occurrenceOverrides,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OccurrenceOverridesTableFilterComposer(
            $db: $db,
            $table: $db.occurrenceOverrides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stageOccurrenceStatesRefs(
    Expression<bool> Function($$StageOccurrenceStatesTableFilterComposer f) f,
  ) {
    final $$StageOccurrenceStatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stageOccurrenceStates,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StageOccurrenceStatesTableFilterComposer(
                $db: $db,
                $table: $db.stageOccurrenceStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusBeforeArchive => $composableBuilder(
    column: $table.statusBeforeArchive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planDate => $composableBuilder(
    column: $table.planDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceExDates => $composableBuilder(
    column: $table.recurrenceExDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get splitFromTaskId => $composableBuilder(
    column: $table.splitFromTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get statusBeforeArchive => $composableBuilder(
    column: $table.statusBeforeArchive,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get planDate =>
      $composableBuilder(column: $table.planDate, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceExDates => $composableBuilder(
    column: $table.recurrenceExDates,
    builder: (column) => column,
  );

  GeneratedColumn<String> get splitFromTaskId => $composableBuilder(
    column: $table.splitFromTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stagesRefs<T extends Object>(
    Expression<T> Function($$StagesTableAnnotationComposer a) f,
  ) {
    final $$StagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stages,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StagesTableAnnotationComposer(
            $db: $db,
            $table: $db.stages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> checklistItemsRefs<T extends Object>(
    Expression<T> Function($$ChecklistItemsTableAnnotationComposer a) f,
  ) {
    final $$ChecklistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checklistItems,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChecklistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.checklistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> occurrenceOverridesRefs<T extends Object>(
    Expression<T> Function($$OccurrenceOverridesTableAnnotationComposer a) f,
  ) {
    final $$OccurrenceOverridesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.occurrenceOverrides,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$OccurrenceOverridesTableAnnotationComposer(
                $db: $db,
                $table: $db.occurrenceOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> stageOccurrenceStatesRefs<T extends Object>(
    Expression<T> Function($$StageOccurrenceStatesTableAnnotationComposer a) f,
  ) {
    final $$StageOccurrenceStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stageOccurrenceStates,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StageOccurrenceStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.stageOccurrenceStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({
            bool categoryId,
            bool stagesRefs,
            bool checklistItemsRefs,
            bool occurrenceOverridesRefs,
            bool stageOccurrenceStatesRefs,
            bool remindersRefs,
            bool taskTagsRefs,
          })
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> statusBeforeArchive = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> planDate = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceExDates = const Value.absent(),
                Value<String?> splitFromTaskId = const Value.absent(),
                Value<int?> colorArgb = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                title: title,
                note: note,
                kind: kind,
                categoryId: categoryId,
                priority: priority,
                status: status,
                statusBeforeArchive: statusBeforeArchive,
                isAllDay: isAllDay,
                planDate: planDate,
                startMinute: startMinute,
                endDate: endDate,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                recurrenceRule: recurrenceRule,
                recurrenceExDates: recurrenceExDates,
                splitFromTaskId: splitFromTaskId,
                colorArgb: colorArgb,
                icon: icon,
                sortOrder: sortOrder,
                completedAt: completedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String title,
                Value<String?> note = const Value.absent(),
                required String kind,
                Value<String?> categoryId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> statusBeforeArchive = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> planDate = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                required String timeZoneId,
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceExDates = const Value.absent(),
                Value<String?> splitFromTaskId = const Value.absent(),
                Value<int?> colorArgb = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                title: title,
                note: note,
                kind: kind,
                categoryId: categoryId,
                priority: priority,
                status: status,
                statusBeforeArchive: statusBeforeArchive,
                isAllDay: isAllDay,
                planDate: planDate,
                startMinute: startMinute,
                endDate: endDate,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                recurrenceRule: recurrenceRule,
                recurrenceExDates: recurrenceExDates,
                splitFromTaskId: splitFromTaskId,
                colorArgb: colorArgb,
                icon: icon,
                sortOrder: sortOrder,
                completedAt: completedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                stagesRefs = false,
                checklistItemsRefs = false,
                occurrenceOverridesRefs = false,
                stageOccurrenceStatesRefs = false,
                remindersRefs = false,
                taskTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stagesRefs) db.stages,
                    if (checklistItemsRefs) db.checklistItems,
                    if (occurrenceOverridesRefs) db.occurrenceOverrides,
                    if (stageOccurrenceStatesRefs) db.stageOccurrenceStates,
                    if (remindersRefs) db.reminders,
                    if (taskTagsRefs) db.taskTags,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$TasksTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$TasksTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stagesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          StageRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._stagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(db, table, p0).stagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (checklistItemsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          ChecklistItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._checklistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).checklistItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (occurrenceOverridesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          OccurrenceOverrideRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._occurrenceOverridesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).occurrenceOverridesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stageOccurrenceStatesRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          StageOccurrenceStateRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._stageOccurrenceStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).stageOccurrenceStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskTagsRefs)
                        await $_getPrefetchedData<
                          TaskRow,
                          $TasksTable,
                          TaskTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({
        bool categoryId,
        bool stagesRefs,
        bool checklistItemsRefs,
        bool occurrenceOverridesRefs,
        bool stageOccurrenceStatesRefs,
        bool remindersRefs,
        bool taskTagsRefs,
      })
    >;
typedef $$StagesTableCreateCompanionBuilder = StagesCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String id,
  required String taskId,
  required String title,
  required int orderIndex,
  Value<int?> startOffsetMinutes,
  Value<int?> durationMinutes,
  Value<int?> colorArgb,
  Value<String> status,
  Value<int?> completedAt,
  Value<int> rowid,
});
typedef $$StagesTableUpdateCompanionBuilder = StagesCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> id,
  Value<String> taskId,
  Value<String> title,
  Value<int> orderIndex,
  Value<int?> startOffsetMinutes,
  Value<int?> durationMinutes,
  Value<int?> colorArgb,
  Value<String> status,
  Value<int?> completedAt,
  Value<int> rowid,
});

final class $$StagesTableReferences
    extends BaseReferences<_$AppDatabase, $StagesTable, StageRow> {
  $$StagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('stages__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $StageOccurrenceStatesTable,
    List<StageOccurrenceStateRow>
  >
  _stageOccurrenceStatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stageOccurrenceStates,
        aliasName: 'stages__id__stage_occurrence_states__stage_id',
      );

  $$StageOccurrenceStatesTableProcessedTableManager
  get stageOccurrenceStatesRefs {
    final manager = $$StageOccurrenceStatesTableTableManager(
      $_db,
      $_db.stageOccurrenceStates,
    ).filter((f) => f.stageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stageOccurrenceStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StagesTableFilterComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffsetMinutes => $composableBuilder(
    column: $table.startOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stageOccurrenceStatesRefs(
    Expression<bool> Function($$StageOccurrenceStatesTableFilterComposer f) f,
  ) {
    final $$StageOccurrenceStatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stageOccurrenceStates,
          getReferencedColumn: (t) => t.stageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StageOccurrenceStatesTableFilterComposer(
                $db: $db,
                $table: $db.stageOccurrenceStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StagesTableOrderingComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffsetMinutes => $composableBuilder(
    column: $table.startOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StagesTable> {
  $$StagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffsetMinutes => $composableBuilder(
    column: $table.startOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stageOccurrenceStatesRefs<T extends Object>(
    Expression<T> Function($$StageOccurrenceStatesTableAnnotationComposer a) f,
  ) {
    final $$StageOccurrenceStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stageOccurrenceStates,
          getReferencedColumn: (t) => t.stageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StageOccurrenceStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.stageOccurrenceStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StagesTable,
          StageRow,
          $$StagesTableFilterComposer,
          $$StagesTableOrderingComposer,
          $$StagesTableAnnotationComposer,
          $$StagesTableCreateCompanionBuilder,
          $$StagesTableUpdateCompanionBuilder,
          (StageRow, $$StagesTableReferences),
          StageRow,
          PrefetchHooks Function({bool taskId, bool stageOccurrenceStatesRefs})
        > {
  $$StagesTableTableManager(_$AppDatabase db, $StagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int?> startOffsetMinutes = const Value.absent(),
                Value<int?> durationMinutes = const Value.absent(),
                Value<int?> colorArgb = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StagesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                title: title,
                orderIndex: orderIndex,
                startOffsetMinutes: startOffsetMinutes,
                durationMinutes: durationMinutes,
                colorArgb: colorArgb,
                status: status,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String taskId,
                required String title,
                required int orderIndex,
                Value<int?> startOffsetMinutes = const Value.absent(),
                Value<int?> durationMinutes = const Value.absent(),
                Value<int?> colorArgb = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StagesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                title: title,
                orderIndex: orderIndex,
                startOffsetMinutes: startOffsetMinutes,
                durationMinutes: durationMinutes,
                colorArgb: colorArgb,
                status: status,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StagesTable, StageRow>(table),
                  $$StagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskId = false, stageOccurrenceStatesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stageOccurrenceStatesRefs) db.stageOccurrenceStates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (taskId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.taskId,
                            referencedTable: $$StagesTableReferences
                                ._taskIdTable(db),
                            referencedColumn: $$StagesTableReferences
                                ._taskIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stageOccurrenceStatesRefs)
                        await $_getPrefetchedData<
                          StageRow,
                          $StagesTable,
                          StageOccurrenceStateRow
                        >(
                          currentTable: table,
                          referencedTable: $$StagesTableReferences
                              ._stageOccurrenceStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StagesTableReferences(
                                db,
                                table,
                                p0,
                              ).stageOccurrenceStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stageId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StagesTable,
      StageRow,
      $$StagesTableFilterComposer,
      $$StagesTableOrderingComposer,
      $$StagesTableAnnotationComposer,
      $$StagesTableCreateCompanionBuilder,
      $$StagesTableUpdateCompanionBuilder,
      (StageRow, $$StagesTableReferences),
      StageRow,
      PrefetchHooks Function({bool taskId, bool stageOccurrenceStatesRefs})
    >;
typedef $$ChecklistItemsTableCreateCompanionBuilder =
    ChecklistItemsCompanion Function({
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      required String lastWriterId,
      Value<String?> remoteVersion,
      required String id,
      required String taskId,
      required String title,
      Value<bool> isDone,
      required int orderIndex,
      Value<int> rowid,
    });
typedef $$ChecklistItemsTableUpdateCompanionBuilder =
    ChecklistItemsCompanion Function({
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      Value<String> lastWriterId,
      Value<String?> remoteVersion,
      Value<String> id,
      Value<String> taskId,
      Value<String> title,
      Value<bool> isDone,
      Value<int> orderIndex,
      Value<int> rowid,
    });

final class $$ChecklistItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChecklistItemsTable, ChecklistItemRow> {
  $$ChecklistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('checklist_items__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChecklistItemsTable> {
  $$ChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChecklistItemsTable,
          ChecklistItemRow,
          $$ChecklistItemsTableFilterComposer,
          $$ChecklistItemsTableOrderingComposer,
          $$ChecklistItemsTableAnnotationComposer,
          $$ChecklistItemsTableCreateCompanionBuilder,
          $$ChecklistItemsTableUpdateCompanionBuilder,
          (ChecklistItemRow, $$ChecklistItemsTableReferences),
          ChecklistItemRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$ChecklistItemsTableTableManager(
    _$AppDatabase db,
    $ChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChecklistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                title: title,
                isDone: isDone,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String taskId,
                required String title,
                Value<bool> isDone = const Value.absent(),
                required int orderIndex,
                Value<int> rowid = const Value.absent(),
              }) => ChecklistItemsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                title: title,
                isDone: isDone,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChecklistItemsTable, ChecklistItemRow>(table),
                  $$ChecklistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$ChecklistItemsTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$ChecklistItemsTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChecklistItemsTable,
      ChecklistItemRow,
      $$ChecklistItemsTableFilterComposer,
      $$ChecklistItemsTableOrderingComposer,
      $$ChecklistItemsTableAnnotationComposer,
      $$ChecklistItemsTableCreateCompanionBuilder,
      $$ChecklistItemsTableUpdateCompanionBuilder,
      (ChecklistItemRow, $$ChecklistItemsTableReferences),
      ChecklistItemRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$OccurrenceOverridesTableCreateCompanionBuilder =
    OccurrenceOverridesCompanion Function({
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      required String lastWriterId,
      Value<String?> remoteVersion,
      required String id,
      required String taskId,
      required String occurrenceKey,
      required String action,
      Value<String?> status,
      Value<int?> completedAt,
      Value<String?> titleOverride,
      Value<String?> noteOverride,
      Value<String?> planDateOverride,
      Value<int?> startMinuteOverride,
      Value<String?> endDateOverride,
      Value<int?> endMinuteOverride,
      Value<int> rowid,
    });
typedef $$OccurrenceOverridesTableUpdateCompanionBuilder =
    OccurrenceOverridesCompanion Function({
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      Value<String> lastWriterId,
      Value<String?> remoteVersion,
      Value<String> id,
      Value<String> taskId,
      Value<String> occurrenceKey,
      Value<String> action,
      Value<String?> status,
      Value<int?> completedAt,
      Value<String?> titleOverride,
      Value<String?> noteOverride,
      Value<String?> planDateOverride,
      Value<int?> startMinuteOverride,
      Value<String?> endDateOverride,
      Value<int?> endMinuteOverride,
      Value<int> rowid,
    });

final class $$OccurrenceOverridesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $OccurrenceOverridesTable,
          OccurrenceOverrideRow
        > {
  $$OccurrenceOverridesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('occurrence_overrides__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OccurrenceOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $OccurrenceOverridesTable> {
  $$OccurrenceOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteOverride => $composableBuilder(
    column: $table.noteOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planDateOverride => $composableBuilder(
    column: $table.planDateOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinuteOverride => $composableBuilder(
    column: $table.startMinuteOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDateOverride => $composableBuilder(
    column: $table.endDateOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinuteOverride => $composableBuilder(
    column: $table.endMinuteOverride,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OccurrenceOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $OccurrenceOverridesTable> {
  $$OccurrenceOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteOverride => $composableBuilder(
    column: $table.noteOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planDateOverride => $composableBuilder(
    column: $table.planDateOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinuteOverride => $composableBuilder(
    column: $table.startMinuteOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDateOverride => $composableBuilder(
    column: $table.endDateOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinuteOverride => $composableBuilder(
    column: $table.endMinuteOverride,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OccurrenceOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OccurrenceOverridesTable> {
  $$OccurrenceOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleOverride => $composableBuilder(
    column: $table.titleOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteOverride => $composableBuilder(
    column: $table.noteOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get planDateOverride => $composableBuilder(
    column: $table.planDateOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMinuteOverride => $composableBuilder(
    column: $table.startMinuteOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endDateOverride => $composableBuilder(
    column: $table.endDateOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinuteOverride => $composableBuilder(
    column: $table.endMinuteOverride,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OccurrenceOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OccurrenceOverridesTable,
          OccurrenceOverrideRow,
          $$OccurrenceOverridesTableFilterComposer,
          $$OccurrenceOverridesTableOrderingComposer,
          $$OccurrenceOverridesTableAnnotationComposer,
          $$OccurrenceOverridesTableCreateCompanionBuilder,
          $$OccurrenceOverridesTableUpdateCompanionBuilder,
          (OccurrenceOverrideRow, $$OccurrenceOverridesTableReferences),
          OccurrenceOverrideRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$OccurrenceOverridesTableTableManager(
    _$AppDatabase db,
    $OccurrenceOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OccurrenceOverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OccurrenceOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OccurrenceOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> occurrenceKey = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> titleOverride = const Value.absent(),
                Value<String?> noteOverride = const Value.absent(),
                Value<String?> planDateOverride = const Value.absent(),
                Value<int?> startMinuteOverride = const Value.absent(),
                Value<String?> endDateOverride = const Value.absent(),
                Value<int?> endMinuteOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccurrenceOverridesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                occurrenceKey: occurrenceKey,
                action: action,
                status: status,
                completedAt: completedAt,
                titleOverride: titleOverride,
                noteOverride: noteOverride,
                planDateOverride: planDateOverride,
                startMinuteOverride: startMinuteOverride,
                endDateOverride: endDateOverride,
                endMinuteOverride: endMinuteOverride,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String taskId,
                required String occurrenceKey,
                required String action,
                Value<String?> status = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> titleOverride = const Value.absent(),
                Value<String?> noteOverride = const Value.absent(),
                Value<String?> planDateOverride = const Value.absent(),
                Value<int?> startMinuteOverride = const Value.absent(),
                Value<String?> endDateOverride = const Value.absent(),
                Value<int?> endMinuteOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccurrenceOverridesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                occurrenceKey: occurrenceKey,
                action: action,
                status: status,
                completedAt: completedAt,
                titleOverride: titleOverride,
                noteOverride: noteOverride,
                planDateOverride: planDateOverride,
                startMinuteOverride: startMinuteOverride,
                endDateOverride: endDateOverride,
                endMinuteOverride: endMinuteOverride,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OccurrenceOverridesTable, OccurrenceOverrideRow>(
                    table,
                  ),
                  $$OccurrenceOverridesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$OccurrenceOverridesTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$OccurrenceOverridesTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OccurrenceOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OccurrenceOverridesTable,
      OccurrenceOverrideRow,
      $$OccurrenceOverridesTableFilterComposer,
      $$OccurrenceOverridesTableOrderingComposer,
      $$OccurrenceOverridesTableAnnotationComposer,
      $$OccurrenceOverridesTableCreateCompanionBuilder,
      $$OccurrenceOverridesTableUpdateCompanionBuilder,
      (OccurrenceOverrideRow, $$OccurrenceOverridesTableReferences),
      OccurrenceOverrideRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$StageOccurrenceStatesTableCreateCompanionBuilder =
    StageOccurrenceStatesCompanion Function({
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      required String lastWriterId,
      Value<String?> remoteVersion,
      required String id,
      required String taskId,
      required String stageId,
      required String occurrenceKey,
      required String status,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$StageOccurrenceStatesTableUpdateCompanionBuilder =
    StageOccurrenceStatesCompanion Function({
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> revision,
      Value<String> lastWriterId,
      Value<String?> remoteVersion,
      Value<String> id,
      Value<String> taskId,
      Value<String> stageId,
      Value<String> occurrenceKey,
      Value<String> status,
      Value<int?> completedAt,
      Value<int> rowid,
    });

final class $$StageOccurrenceStatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StageOccurrenceStatesTable,
          StageOccurrenceStateRow
        > {
  $$StageOccurrenceStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('stage_occurrence_states__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StagesTable _stageIdTable(_$AppDatabase db) =>
      db.stages.createAlias('stage_occurrence_states__stage_id__stages__id');

  $$StagesTableProcessedTableManager get stageId {
    final $_column = $_itemColumn<String>('stage_id')!;

    final manager = $$StagesTableTableManager(
      $_db,
      $_db.stages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StageOccurrenceStatesTableFilterComposer
    extends Composer<_$AppDatabase, $StageOccurrenceStatesTable> {
  $$StageOccurrenceStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StagesTableFilterComposer get stageId {
    final $$StagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stageId,
      referencedTable: $db.stages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StagesTableFilterComposer(
            $db: $db,
            $table: $db.stages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageOccurrenceStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $StageOccurrenceStatesTable> {
  $$StageOccurrenceStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StagesTableOrderingComposer get stageId {
    final $$StagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stageId,
      referencedTable: $db.stages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StagesTableOrderingComposer(
            $db: $db,
            $table: $db.stages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageOccurrenceStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StageOccurrenceStatesTable> {
  $$StageOccurrenceStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StagesTableAnnotationComposer get stageId {
    final $$StagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stageId,
      referencedTable: $db.stages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StagesTableAnnotationComposer(
            $db: $db,
            $table: $db.stages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageOccurrenceStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StageOccurrenceStatesTable,
          StageOccurrenceStateRow,
          $$StageOccurrenceStatesTableFilterComposer,
          $$StageOccurrenceStatesTableOrderingComposer,
          $$StageOccurrenceStatesTableAnnotationComposer,
          $$StageOccurrenceStatesTableCreateCompanionBuilder,
          $$StageOccurrenceStatesTableUpdateCompanionBuilder,
          (StageOccurrenceStateRow, $$StageOccurrenceStatesTableReferences),
          StageOccurrenceStateRow,
          PrefetchHooks Function({bool taskId, bool stageId})
        > {
  $$StageOccurrenceStatesTableTableManager(
    _$AppDatabase db,
    $StageOccurrenceStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StageOccurrenceStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StageOccurrenceStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StageOccurrenceStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> stageId = const Value.absent(),
                Value<String> occurrenceKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StageOccurrenceStatesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                stageId: stageId,
                occurrenceKey: occurrenceKey,
                status: status,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String taskId,
                required String stageId,
                required String occurrenceKey,
                required String status,
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StageOccurrenceStatesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                stageId: stageId,
                occurrenceKey: occurrenceKey,
                status: status,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $StageOccurrenceStatesTable,
                    StageOccurrenceStateRow
                  >(table),
                  $$StageOccurrenceStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, stageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$StageOccurrenceStatesTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$StageOccurrenceStatesTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (stageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.stageId,
                        referencedTable: $$StageOccurrenceStatesTableReferences
                            ._stageIdTable(db),
                        referencedColumn: $$StageOccurrenceStatesTableReferences
                            ._stageIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StageOccurrenceStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StageOccurrenceStatesTable,
      StageOccurrenceStateRow,
      $$StageOccurrenceStatesTableFilterComposer,
      $$StageOccurrenceStatesTableOrderingComposer,
      $$StageOccurrenceStatesTableAnnotationComposer,
      $$StageOccurrenceStatesTableCreateCompanionBuilder,
      $$StageOccurrenceStatesTableUpdateCompanionBuilder,
      (StageOccurrenceStateRow, $$StageOccurrenceStatesTableReferences),
      StageOccurrenceStateRow,
      PrefetchHooks Function({bool taskId, bool stageId})
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String id,
  required String taskId,
  required String kind,
  Value<int?> offsetMinutes,
  Value<String?> absoluteDate,
  Value<int?> absoluteMinute,
  Value<bool> isEnabled,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> id,
  Value<String> taskId,
  Value<String> kind,
  Value<int?> offsetMinutes,
  Value<String?> absoluteDate,
  Value<int?> absoluteMinute,
  Value<bool> isEnabled,
  Value<int> rowid,
});

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('reminders__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get absoluteDate => $composableBuilder(
    column: $table.absoluteDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get absoluteMinute => $composableBuilder(
    column: $table.absoluteMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get absoluteDate => $composableBuilder(
    column: $table.absoluteDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get absoluteMinute => $composableBuilder(
    column: $table.absoluteMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get absoluteDate => $composableBuilder(
    column: $table.absoluteDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get absoluteMinute => $composableBuilder(
    column: $table.absoluteMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> offsetMinutes = const Value.absent(),
                Value<String?> absoluteDate = const Value.absent(),
                Value<int?> absoluteMinute = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                kind: kind,
                offsetMinutes: offsetMinutes,
                absoluteDate: absoluteDate,
                absoluteMinute: absoluteMinute,
                isEnabled: isEnabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String taskId,
                required String kind,
                Value<int?> offsetMinutes = const Value.absent(),
                Value<String?> absoluteDate = const Value.absent(),
                Value<int?> absoluteMinute = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                taskId: taskId,
                kind: kind,
                offsetMinutes: offsetMinutes,
                absoluteDate: absoluteDate,
                absoluteMinute: absoluteMinute,
                isEnabled: isEnabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$RemindersTableReferences
                            ._taskIdTable(db),
                        referencedColumn: $$RemindersTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String id,
  required String name,
  required int colorArgb,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> id,
  Value<String> name,
  Value<int> colorArgb,
  Value<int> rowid,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTagRow>>
  _taskTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: 'tags__id__task_tags__tag_id',
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool taskTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                name: name,
                colorArgb: colorArgb,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String id,
                required String name,
                required int colorArgb,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                id: id,
                name: name,
                colorArgb: colorArgb,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskTagsRefs) db.taskTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskTagsRefs)
                    await $_getPrefetchedData<TagRow, $TagsTable, TaskTagRow>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._taskTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).taskTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool taskTagsRefs})
    >;
typedef $$TaskTagsTableCreateCompanionBuilder = TaskTagsCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String taskId,
  required String tagId,
  Value<int> rowid,
});
typedef $$TaskTagsTableUpdateCompanionBuilder = TaskTagsCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> taskId,
  Value<String> tagId,
  Value<int> rowid,
});

final class $$TaskTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTagRow> {
  $$TaskTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_tags__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('task_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTagsTable,
          TaskTagRow,
          $$TaskTagsTableFilterComposer,
          $$TaskTagsTableOrderingComposer,
          $$TaskTagsTableAnnotationComposer,
          $$TaskTagsTableCreateCompanionBuilder,
          $$TaskTagsTableUpdateCompanionBuilder,
          (TaskTagRow, $$TaskTagsTableReferences),
          TaskTagRow,
          PrefetchHooks Function({bool taskId, bool tagId})
        > {
  $$TaskTagsTableTableManager(_$AppDatabase db, $TaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String taskId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskTagsTable, TaskTagRow>(table),
                  $$TaskTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$TaskTagsTableReferences._taskIdTable(
                          db,
                        ),
                        referencedColumn: $$TaskTagsTableReferences
                            ._taskIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$TaskTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$TaskTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTagsTable,
      TaskTagRow,
      $$TaskTagsTableFilterComposer,
      $$TaskTagsTableOrderingComposer,
      $$TaskTagsTableAnnotationComposer,
      $$TaskTagsTableCreateCompanionBuilder,
      $$TaskTagsTableUpdateCompanionBuilder,
      (TaskTagRow, $$TaskTagsTableReferences),
      TaskTagRow,
      PrefetchHooks Function({bool taskId, bool tagId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  required String lastWriterId,
  Value<String?> remoteVersion,
  required String key,
  required String valueJson,
  required String scope,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> revision,
  Value<String> lastWriterId,
  Value<String?> remoteVersion,
  Value<String> key,
  Value<String> valueJson,
  Value<String> scope,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastWriterId => $composableBuilder(
    column: $table.lastWriterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteVersion => $composableBuilder(
    column: $table.remoteVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastWriterId = const Value.absent(),
                Value<String?> remoteVersion = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                key: key,
                valueJson: valueJson,
                scope: scope,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String lastWriterId,
                Value<String?> remoteVersion = const Value.absent(),
                required String key,
                required String valueJson,
                required String scope,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastWriterId: lastWriterId,
                remoteVersion: remoteVersion,
                key: key,
                valueJson: valueJson,
                scope: scope,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ScheduledNotificationsTableCreateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      Value<int> osNotificationId,
      required String reminderId,
      required String taskId,
      required String occurrenceKey,
      required int fireAtInstant,
      required String state,
    });
typedef $$ScheduledNotificationsTableUpdateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      Value<int> osNotificationId,
      Value<String> reminderId,
      Value<String> taskId,
      Value<String> occurrenceKey,
      Value<int> fireAtInstant,
      Value<String> state,
    });

class $$ScheduledNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fireAtInstant => $composableBuilder(
    column: $table.fireAtInstant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fireAtInstant => $composableBuilder(
    column: $table.fireAtInstant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get occurrenceKey => $composableBuilder(
    column: $table.occurrenceKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fireAtInstant => $composableBuilder(
    column: $table.fireAtInstant,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$ScheduledNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotificationRow,
          $$ScheduledNotificationsTableFilterComposer,
          $$ScheduledNotificationsTableOrderingComposer,
          $$ScheduledNotificationsTableAnnotationComposer,
          $$ScheduledNotificationsTableCreateCompanionBuilder,
          $$ScheduledNotificationsTableUpdateCompanionBuilder,
          (
            ScheduledNotificationRow,
            BaseReferences<
              _$AppDatabase,
              $ScheduledNotificationsTable,
              ScheduledNotificationRow
            >,
          ),
          ScheduledNotificationRow,
          PrefetchHooks Function()
        > {
  $$ScheduledNotificationsTableTableManager(
    _$AppDatabase db,
    $ScheduledNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledNotificationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledNotificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledNotificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> osNotificationId = const Value.absent(),
                Value<String> reminderId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> occurrenceKey = const Value.absent(),
                Value<int> fireAtInstant = const Value.absent(),
                Value<String> state = const Value.absent(),
              }) => ScheduledNotificationsCompanion(
                osNotificationId: osNotificationId,
                reminderId: reminderId,
                taskId: taskId,
                occurrenceKey: occurrenceKey,
                fireAtInstant: fireAtInstant,
                state: state,
              ),
          createCompanionCallback:
              ({
                Value<int> osNotificationId = const Value.absent(),
                required String reminderId,
                required String taskId,
                required String occurrenceKey,
                required int fireAtInstant,
                required String state,
              }) => ScheduledNotificationsCompanion.insert(
                osNotificationId: osNotificationId,
                reminderId: reminderId,
                taskId: taskId,
                occurrenceKey: occurrenceKey,
                fireAtInstant: fireAtInstant,
                state: state,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledNotificationsTable,
                    ScheduledNotificationRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScheduledNotificationsTable,
                    ScheduledNotificationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledNotificationsTable,
      ScheduledNotificationRow,
      $$ScheduledNotificationsTableFilterComposer,
      $$ScheduledNotificationsTableOrderingComposer,
      $$ScheduledNotificationsTableAnnotationComposer,
      $$ScheduledNotificationsTableCreateCompanionBuilder,
      $$ScheduledNotificationsTableUpdateCompanionBuilder,
      (
        ScheduledNotificationRow,
        BaseReferences<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotificationRow
        >,
      ),
      ScheduledNotificationRow,
      PrefetchHooks Function()
    >;
typedef $$ChangeLogTableCreateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> seq,
  required String entityType,
  required String entityId,
  required String op,
  Value<String?> payloadJson,
  required int occurredAt,
  required String deviceId,
  Value<int?> syncedAt,
});
typedef $$ChangeLogTableUpdateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> seq,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> op,
  Value<String?> payloadJson,
  Value<int> occurredAt,
  Value<String> deviceId,
  Value<int?> syncedAt,
});

class $$ChangeLogTableFilterComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangeLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangeLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ChangeLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChangeLogTable,
          ChangeLogRow,
          $$ChangeLogTableFilterComposer,
          $$ChangeLogTableOrderingComposer,
          $$ChangeLogTableAnnotationComposer,
          $$ChangeLogTableCreateCompanionBuilder,
          $$ChangeLogTableUpdateCompanionBuilder,
          (
            ChangeLogRow,
            BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>,
          ),
          ChangeLogRow,
          PrefetchHooks Function()
        > {
  $$ChangeLogTableTableManager(_$AppDatabase db, $ChangeLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangeLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangeLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangeLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
              }) => ChangeLogCompanion(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                op: op,
                payloadJson: payloadJson,
                occurredAt: occurredAt,
                deviceId: deviceId,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String entityType,
                required String entityId,
                required String op,
                Value<String?> payloadJson = const Value.absent(),
                required int occurredAt,
                required String deviceId,
                Value<int?> syncedAt = const Value.absent(),
              }) => ChangeLogCompanion.insert(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                op: op,
                payloadJson: payloadJson,
                occurredAt: occurredAt,
                deviceId: deviceId,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangeLogTable, ChangeLogRow>(table),
                  BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangeLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChangeLogTable,
      ChangeLogRow,
      $$ChangeLogTableFilterComposer,
      $$ChangeLogTableOrderingComposer,
      $$ChangeLogTableAnnotationComposer,
      $$ChangeLogTableCreateCompanionBuilder,
      $$ChangeLogTableUpdateCompanionBuilder,
      (
        ChangeLogRow,
        BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogRow>,
      ),
      ChangeLogRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$StagesTableTableManager get stages =>
      $$StagesTableTableManager(_db, _db.stages);
  $$ChecklistItemsTableTableManager get checklistItems =>
      $$ChecklistItemsTableTableManager(_db, _db.checklistItems);
  $$OccurrenceOverridesTableTableManager get occurrenceOverrides =>
      $$OccurrenceOverridesTableTableManager(_db, _db.occurrenceOverrides);
  $$StageOccurrenceStatesTableTableManager get stageOccurrenceStates =>
      $$StageOccurrenceStatesTableTableManager(_db, _db.stageOccurrenceStates);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db, _db.taskTags);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ScheduledNotificationsTableTableManager get scheduledNotifications =>
      $$ScheduledNotificationsTableTableManager(
        _db,
        _db.scheduledNotifications,
      );
  $$ChangeLogTableTableManager get changeLog =>
      $$ChangeLogTableTableManager(_db, _db.changeLog);
}
