import 'package:flutter/material.dart';

/// Date formatting shared by social timelines.
///
/// The Threads-style timeline deliberately shows a concise localized date,
/// rather than exposing the raw ISO timestamp returned by the API.
class AppDateFormat {
  AppDateFormat._();

  static String threadDate(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
}
