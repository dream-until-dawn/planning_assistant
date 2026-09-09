/// 动效开关（design-system §7、view-specs §3.2）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'registry.dart';
import 'settings_providers.dart';

/// 现在该不该关掉动效。
///
/// **应用内的开关与系统设置取「或」**（settings-spec §2.1 那一行的原话）。
///
/// 只看应用内的话，用户在系统里打开「减少动态效果」之后还得再来这里
/// 关一次 —— 那等于没有响应系统设置，而对前庭失调的用户来说，
/// 一次没预料到的滑动动画就足够引发不适。
///
/// 只看系统的话，那个开关又变成不可覆盖的 —— 有人只想关掉这个应用的动画。
///
/// 取「或」是唯一两边都成立的读法。
bool reducedMotionOf(BuildContext context, WidgetRef ref) =>
    MediaQuery.disableAnimationsOf(context) || ref.setting(reduceMotion);
