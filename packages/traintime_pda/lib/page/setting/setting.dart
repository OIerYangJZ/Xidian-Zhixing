// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Setting window.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:watermeter/controller/experiment_controller.dart';
import 'package:watermeter/page/homepage/info_widget/classtable_card.dart';
import 'package:watermeter/page/homepage/refresh.dart';
import 'package:watermeter/page/public_widget/context_extension.dart';
import 'package:watermeter/page/setting/dialogs/change_color_dialog.dart';
import 'package:watermeter/page/setting/dialogs/electricity_account_dialog.dart';
import 'package:watermeter/page/setting/dialogs/schoolnet_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/semester_switch_dialog.dart';
import 'package:watermeter/page/setting/notification_page/notification_page.dart';
import 'package:watermeter/page/public_widget/toast.dart';
import 'package:get/get.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/page/setting/about_page/about_page.dart';
import 'package:watermeter/page/setting/dialogs/experiment_password_dialog.dart';
import 'package:watermeter/repository/pick_file.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/page/setting/dialogs/electricity_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/sport_password_dialog.dart';
import 'package:watermeter/page/setting/dialogs/change_swift_dialog.dart';
import 'package:watermeter/repository/network_session.dart';
import 'package:watermeter/repository/xidian_ids/classtable_session.dart';
import 'package:watermeter/repository/xidian_ids/electricity_session.dart'
    as electricity_session;
import 'package:watermeter/repository/xidian_ids/personal_info_session.dart';
import 'package:watermeter/themes/color_seed.dart';

class SettingWindow extends StatefulWidget {
  const SettingWindow({super.key});
  @override
  State<SettingWindow> createState() => _SettingWindowState();
}

class _SettingWindowState extends State<SettingWindow> {
  Widget _buildSectionCard({required String title, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isLightMode ? Colors.white : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    final pageBackgroundColor = isLightMode
        ? Colors.white
        : colorScheme.surface;
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: pageBackgroundColor,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        title: Text(
          FlutterI18n.translate(context, "homepage.setting"),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              children: [
                const SizedBox(height: 8),
                _buildSectionCard(
                  title: FlutterI18n.translate(context, "setting.ui_setting"),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.color_setting",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.change_color_dialog.${ColorSeed.values[preference.getInt(preference.Preference.color)].label}",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => const ChangeColorDialog(),
                          );
                        },
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.timeline_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.simplify_timeline",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.simplify_timeline_description",
                          ),
                        ),
                        trailing: Switch(
                          value: preference.getBool(
                            preference.Preference.simplifiedClassTimeline,
                          ),
                          onChanged: (bool value) {
                            setState(() {
                              preference
                                  .setBool(
                                    preference
                                        .Preference
                                        .simplifiedClassTimeline,
                                    value,
                                  )
                                  .then(
                                    (value) =>
                                        ClassTableCard.reloadSettingsFromPref(),
                                  );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: FlutterI18n.translate(
                    context,
                    "setting.account_setting",
                  ),
                  child: Column(
                    children: [
                      if (!preference.getBool(preference.Preference.role)) ...[
                        ListTile(
                          leading: const Icon(Icons.fitness_center_outlined),
                          title: Text(
                            FlutterI18n.translate(
                              context,
                              "setting.sport_password_setting",
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showDialog(
                              barrierDismissible: false,
                              context: context,
                              builder: (context) => const SportPasswordDialog(),
                            );
                          },
                        ),
                        const Divider(height: 0.5, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.science_outlined),
                          title: Text(
                            FlutterI18n.translate(
                              context,
                              "setting.experiment_password_setting",
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showDialog(
                              barrierDismissible: false,
                              context: context,
                              builder: (context) =>
                                  const ExperimentPasswordDialog(),
                            );
                          },
                        ),
                        const Divider(height: 0.5, indent: 56),
                      ],
                      ListTile(
                        leading: const Icon(Icons.bolt_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.electricity_account_setting",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog<bool>(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) => ElectricityAccountDialog(
                              onSaveAccount: (accountNumber) async {
                                await preference.setString(
                                  preference.Preference.electricityAccount,
                                  accountNumber,
                                );
                              },
                              initialAccountNumber: preference.getString(
                                preference.Preference.electricityAccount,
                              ),
                              onFetchFromNetwork: () async {
                                String dorm = await PersonalInfoSession()
                                    .getDormInfoEhall();
                                return electricity_session
                                    .ElectricitySession.parseElectricityAccountFromIDS(
                                  dorm,
                                );
                              },
                            ),
                          ).then((value) async {
                            if (value != true) {
                              if (context.mounted) {
                                showToast(
                                  context: context,
                                  msg: FlutterI18n.translate(
                                    context,
                                    "setting.change_electricity_account.no_setting",
                                  ),
                                );
                                return;
                              }
                            }

                            electricity_session
                                .ElectricitySession.clearElectricityHistory();

                            if (context.mounted) {
                              showToast(
                                context: context,
                                msg: FlutterI18n.translate(
                                  context,
                                  "setting.change_electricity_account.successful_setting",
                                ),
                              );
                              electricity_session.update(force: true);
                              return;
                            }
                          });
                        },
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.electricity_password_setting",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.electricity_password_description",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                const ElectricityPasswordDialog(),
                          );
                        },
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.wifi_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.schoolnet_password_setting",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.schoolnet_password_description",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                const SchoolNetPasswordDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (Platform.isAndroid || Platform.isIOS)
                  _buildSectionCard(
                    title: FlutterI18n.translate(
                      context,
                      "setting.notification_setting",
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: Text(
                            FlutterI18n.translate(
                              context,
                              "setting.course_reminder_setting",
                            ),
                          ),
                          subtitle: Text(
                            FlutterI18n.translate(
                              context,
                              "setting.course_reminder_description",
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            context.push(const NotificationSettingsPage());
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: FlutterI18n.translate(
                    context,
                    "setting.classtable_setting",
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.wallpaper_outlined),
                        title: Text(
                          FlutterI18n.translate(context, "setting.background"),
                        ),
                        trailing: Switch(
                          value: preference.getBool(
                            preference.Preference.decorated,
                          ),
                          onChanged: (bool value) {
                            if (value == true &&
                                !preference.getBool(
                                  preference.Preference.decoration,
                                )) {
                              showToast(
                                context: context,
                                msg: FlutterI18n.translate(
                                  context,
                                  "setting.no_background",
                                ),
                              );
                            } else {
                              setState(() {
                                preference.setBool(
                                  preference.Preference.decorated,
                                  value,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.choose_background",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          FilePickerResult? result;
                          try {
                            result = await pickFile(type: FileType.image);
                          } on MissingStoragePermissionException {
                            if (context.mounted) {
                              showToast(
                                context: context,
                                msg: FlutterI18n.translate(
                                  context,
                                  "setting.no_permission",
                                ),
                              );
                            }
                          }
                          if (mounted) {
                            if (result != null) {
                              File(result.files.single.path!).copySync(
                                "${supportPath.path}/${ClassTableFile.decorationName}",
                              );
                              preference.setBool(
                                preference.Preference.decoration,
                                true,
                              );
                              if (context.mounted) {
                                showToast(
                                  context: context,
                                  msg: FlutterI18n.translate(
                                    context,
                                    "setting.successful_setting",
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                showToast(
                                  context: context,
                                  msg: FlutterI18n.translate(
                                    context,
                                    "setting.failure_setting",
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.clear_user_class",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text(
                              FlutterI18n.translate(
                                context,
                                "setting.clear_user_class_title",
                              ),
                            ),
                            content: Text(
                              FlutterI18n.translate(
                                context,
                                "setting.clear_user_class_content",
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  FlutterI18n.translate(context, "cancel"),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  var file = File(
                                    "${supportPath.path}/"
                                    "${ClassTableFile.userDefinedClassName}",
                                  );
                                  if (file.existsSync()) {
                                    file.deleteSync();
                                  }
                                  Get.find<ClassTableController>()
                                      .updateClassTable();
                                  showToast(
                                    context: context,
                                    msg: FlutterI18n.translate(
                                      context,
                                      "setting.clear_user_class_clear",
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  FlutterI18n.translate(context, "confirm"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.sync_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.class_refresh",
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text(
                              FlutterI18n.translate(
                                context,
                                "setting.class_refresh_title",
                              ),
                            ),
                            content: Text(
                              FlutterI18n.translate(
                                context,
                                "setting.class_refresh_content",
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  FlutterI18n.translate(context, "cancel"),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Future.wait([
                                    Get.put(
                                      ClassTableController(),
                                    ).updateClassTable(isForce: true),
                                    Get.put(ExamController()).get(),
                                    Get.put(ExperimentController()).get(),
                                  ]).then((value) => value.first);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  FlutterI18n.translate(context, "confirm"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.swap_vert_outlined),
                        title: Text(
                          FlutterI18n.translate(context, "setting.class_swift"),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.class_swift_description",
                            translationParams: {
                              "swift": preference
                                  .getInt(preference.Preference.swift)
                                  .toString(),
                            },
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) => ChangeSwiftDialog(),
                          ).then((value) {
                            Get.put(ClassTableController()).update();
                            updateCurrentData();
                            setState(() {});
                          });
                        },
                      ),
                      const Divider(height: 0.5, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.semester_change",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.semester_change_description",
                            translationParams: {
                              "semester": preference.getString(
                                preference.Preference.currentSemester,
                              ),
                            },
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog<bool>(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) => SemesterSwitchDialog(),
                          ).then((value) {
                            if (value == true) {
                              setState(() {});
                              if (context.mounted) {
                                showToast(
                                  context: context,
                                  msg: "Updating data",
                                );
                              }
                              Get.put(
                                ClassTableController(),
                              ).updateClassTable(isForce: true);
                              Get.put(ExamController()).get();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: FlutterI18n.translate(context, "setting.about"),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.about_this_program",
                          ),
                        ),
                        subtitle: Text(
                          FlutterI18n.translate(
                            context,
                            "setting.version",
                            translationParams: {
                              "version":
                                  "${preference.packageInfo.version}+"
                                  "${preference.packageInfo.buildNumber}",
                            },
                          ),
                        ),
                        onTap: () => context.pushReplacement(const AboutPage()),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
