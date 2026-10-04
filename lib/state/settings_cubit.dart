import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store.dart';
import '../engine/astro/ayanamsa.dart';
import '../widgets/chart/chart_styles.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.languageCode = 'hi',
    this.ayanamsa = Ayanamsa.lahiri,
    this.chartStyle = ChartStyle.north,
    this.largeText = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        languageCode: (json['lang'] as String?) ?? 'hi',
        ayanamsa: Ayanamsa.values.firstWhere(
          (Ayanamsa a) => a.name == json['ayanamsa'],
          orElse: () => Ayanamsa.lahiri,
        ),
        chartStyle: ChartStyle.values.firstWhere(
          (ChartStyle s) => s.name == json['chartStyle'],
          orElse: () => ChartStyle.north,
        ),
        largeText: (json['largeText'] as bool?) ?? false,
      );

  final String languageCode;
  final Ayanamsa ayanamsa;
  final ChartStyle chartStyle;
  final bool largeText;

  Locale get locale => Locale(languageCode);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lang': languageCode,
        'ayanamsa': ayanamsa.name,
        'chartStyle': chartStyle.name,
        'largeText': largeText,
      };

  AppSettings copyWith({
    String? languageCode,
    Ayanamsa? ayanamsa,
    ChartStyle? chartStyle,
    bool? largeText,
  }) =>
      AppSettings(
        languageCode: languageCode ?? this.languageCode,
        ayanamsa: ayanamsa ?? this.ayanamsa,
        chartStyle: chartStyle ?? this.chartStyle,
        largeText: largeText ?? this.largeText,
      );

  @override
  List<Object?> get props => <Object?>[languageCode, ayanamsa, chartStyle, largeText];
}

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._store)
      : super(AppSettings.fromJson(_store.readMap(StoreKeys.settings)));

  final LocalStore _store;

  Future<void> _save(AppSettings next) async {
    emit(next);
    await _store.writeMap(StoreKeys.settings, next.toJson());
  }

  Future<void> setLanguage(String code) => _save(state.copyWith(languageCode: code));

  Future<void> setAyanamsa(Ayanamsa value) => _save(state.copyWith(ayanamsa: value));

  Future<void> setChartStyle(ChartStyle value) =>
      _save(state.copyWith(chartStyle: value));

  Future<void> setLargeText(bool value) => _save(state.copyWith(largeText: value));
}
