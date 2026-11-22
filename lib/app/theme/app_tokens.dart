import 'package:flutter/material.dart';

/// 设计令牌：间距 / 圆角 / 动效时长 / 尺寸 / 品牌色。
///
/// 所有页面只用这里的常量，禁止散落魔法数字——改一套值即可全局生效。
class AppSpacing {
  AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  static const EdgeInsets page = EdgeInsets.fromLTRB(xl, xl, xl, xxl);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets itemGap = EdgeInsets.only(bottom: md);
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

class AppDurations {
  AppDurations._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}

class AppSizes {
  AppSizes._();
  static const double railWidth = 92;
  static const double railLabelGap = 6;
  static const double navBarHeight = 68;
  static const double maxContentWidth = 1320;
  static const double pageHeaderHeight = 64;
}

class AppColors {
  AppColors._();

  /// 品牌种子色（与图标暖紫色调呼应）。
  static const Color seed = Color(0xFF7C5CFF);

  static const Color darkBg = Color(0xFF0E0E12);
  static const Color darkSurface = Color(0xFF16161D);
  static const Color darkSurfaceHigh = Color(0xFF1D1D26);
  static const Color darkBorder = Color(0xFF262633);
  static const Color darkTextPrimary = Color(0xFFF1F1F6);
  static const Color darkTextSecondary = Color(0xFF9A9AA8);

  static const Color lightBg = Color(0xFFF5F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE3E3EA);
}
