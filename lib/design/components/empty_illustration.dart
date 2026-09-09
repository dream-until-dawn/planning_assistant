/// 空态插画（design-system §8.2、FR-VIEW-02 验收「空态有插画与引导」）。
///
/// ## 上一版是「圆底 + Material 图标」
///
/// 那是个占位。规格要的是**插画**，而一个 `Icons.wb_sunny_outlined` 摆在
/// 灰圆里，读起来是「这里应该有张图，但还没画」——
/// 恰恰是 §8.2 那句「最容易让人觉得『这 App 没做完』」说的那种观感。
///
/// ## 为什么是画的，不是图片
///
/// **不引外部资源**，理由三条，一条比一条硬：
///
///  · V1 不联网（NFR-PRIV-01），资源只能打进包里；
///  · 空态有六种，位图要按 1x/2x/3x 各打一份 —— 十八张图，包体积线性长；
///  · **位图不跟主题走。** 深色模式下浅色插画会像一块贴纸，
///    而 `CustomPaint` 读的是 token，深浅、品牌色改了它自己跟着变。
///
/// ## 六张图共用一套视觉语言
///
/// 都是「一块柔和的色斑 + 两三笔线条 + 几个小点」：
///
/// - **色斑不是正圆**（[_blob]）—— 四段贝塞尔各用不同半径，
///   得到一个手绘感的不规则形。正圆太规整，与「可爱清新」不搭；
/// - **线条圆头圆角**，粗细统一 [_strokeWidth]；
/// - **小点是不对称的**，两颗一大一小，位置偏一边 —— 摆对称了就成了图标。
///
/// 少了这套共用语言，六张图会像从六个地方抄来的。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 画哪一张。
///
/// **按「空的是什么」分，不按「哪个页面」分** —— 同一种空在三个页面
/// 出现（读库失败在四个视图里都有）时，它们该长得一样。
enum EmptyMotif {
  /// 没有排着的事。太阳 —— 说的是「今天很轻松」，不是「你什么都没做」。
  calm,

  /// 一条任务都没有。一张便签。
  note,

  /// 这段时间没有跨度可画（甘特）。三根长短不一的条。
  span,

  /// 筛完之后没剩下。漏斗。
  filtered,

  /// 空容器：回收站、归档、分类表。
  box,

  /// 读不出来。一朵云加一道斜杠。
  offline,
}

/// 空态上面那张画。
///
/// 装饰性的：**不产出任何语义**（信息在下面那句文案里）。
/// `CustomPaint` 默认就不产出，所以这里不必再包 `ExcludeSemantics` ——
/// 包了反而像是在挡什么。
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({required this.motif, super.key});

  final EmptyMotif motif;

  /// 画布边长。所有坐标都按这个尺寸写死，缩放交给 `CustomPaint`。
  static const double size = 120;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmptyPainter(
          motif: motif,
          // ## 色斑用 `sunken`，线条用 `brandGraphic`
          //
          // 这一对**不是随便挑的**，是设计系统里已经验过的那一对：
          // `primaryGraphic` 对三个亮表面（canvas / card / sunken）
          // 是 3.08–3.46，`primaryDark` 对三个暗表面是 6.17–7.46
          // （见 `colors.dart` 里那两段与 `contrast_test.dart`）。
          // 图形级要 ≥3:1（§10.2），所以拿现成的保证，不自己造。
          //
          // 走过两条弯路，都记在这儿：
          //
          //  · 第一版是「色斑 `brandFill`、线条 `brandGraphic`」。浅色下好看，
          //    而 `AppTheme.dark()` 把 brandFill / brandGraphic / brandText
          //    **设成了同一个值** —— 深色下六张画全成了纯色块。金标一拍就露了。
          //  · 第二版改成「同色的两个透明度」，以为反差就跟 token 无关了。
          //    浅色下只有 **2.85:1** —— `primaryGraphic` 自己对白底才 3.35，
          //    再拿它的淡色版当底，怎么调 alpha 都挤不出 3:1。
          //    那次是反差断言拦下的，不是眼睛。
          blob: colors.sunken,
          ink: colors.brandGraphic,
        ),
      ),
    );
  }
}

const double _strokeWidth = 3;

/// 小点的透明度。看得见，但不抢戏。
const double _sparkleAlpha = 0.45;

/// 画布中心。
const Offset _c = Offset(
  EmptyIllustration.size / 2,
  EmptyIllustration.size / 2,
);

class _EmptyPainter extends CustomPainter {
  const _EmptyPainter({
    required this.motif,
    required this.blob,
    required this.ink,
  });

  final EmptyMotif motif;
  final Color blob;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    // 按实际尺寸缩放，坐标全按 120 写 —— 大字号下空态会被放大，
    // 那时插画跟着长，而不是糊成一团。
    final scale = size.shortestSide / EmptyIllustration.size;
    canvas.scale(scale);

    canvas.drawPath(_blob(), Paint()..color = blob);
    _sparkles(canvas);

    final pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (motif) {
      case EmptyMotif.calm:
        _calm(canvas, pen);
      case EmptyMotif.note:
        _note(canvas, pen);
      case EmptyMotif.span:
        _span(canvas, pen);
      case EmptyMotif.filtered:
        _filtered(canvas, pen);
      case EmptyMotif.box:
        _box(canvas, pen);
      case EmptyMotif.offline:
        _offline(canvas, pen);
    }
  }

  /// 手绘感的色斑：四段贝塞尔，四个半径各不相同。
  ///
  /// 半径全相等就是一个正圆 —— 规整、冷淡，与「可爱清新」不搭。
  /// 这几个数没有公式，是调出来的：**差得太少看不出手绘感，
  /// 差得太多像画歪了**。
  Path _blob() {
    // 五个方向、五个不同的半径，起始角还偏了一点 ——
    // 四个方向的话，无论半径怎么给都是个规规矩矩的椭圆
    // （上下一对、左右一对），看不出手绘感。第一版就是那样，
    // 而注释里却写着「不规则」—— **图不认字**，所以改的是图。
    const radii = [47.0, 39.0, 44.0, 41.0, 45.0];
    const tilt = 0.4;
    final n = radii.length;
    final step = 2 * math.pi / n;

    Offset at(int i) =>
        _c + Offset.fromDirection(i * step - math.pi / 2 + tilt, radii[i % n]);

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 0; i < n; i++) {
      final from = at(i);
      final to = at(i + 1);
      // 控制点朝各自的切线方向推出去 —— 圆的贝塞尔近似手法，
      // 用在不等半径上就得到平滑的不规则形。
      // 系数按段数换算：段越少每段越长，推得也要越远。
      final k = 4 / 3 * math.tan(step / 4);
      final a1 = i * step - math.pi / 2 + tilt + math.pi / 2;
      final a2 = (i + 1) * step - math.pi / 2 + tilt - math.pi / 2;
      final r1 = radii[i % n] * k;
      final r2 = radii[(i + 1) % n] * k;
      path.cubicTo(
        from.dx + math.cos(a1) * r1,
        from.dy + math.sin(a1) * r1,
        to.dx + math.cos(a2) * r2,
        to.dy + math.sin(a2) * r2,
        to.dx,
        to.dy,
      );
    }
    return path..close();
  }

  /// 两颗小点，**一大一小、偏在一边**。
  ///
  /// 摆对称的话它们会读成图标的一部分；偏着才像是「洒在旁边的」。
  void _sparkles(Canvas canvas) {
    final dot = Paint()..color = ink.withValues(alpha: _sparkleAlpha);
    canvas.drawCircle(const Offset(98, 30), 4, dot);
    canvas.drawCircle(const Offset(22, 88), 2.5, dot);
  }

  /// 太阳：一个圆 + 六道短射线。
  void _calm(Canvas canvas, Paint pen) {
    canvas.drawCircle(_c, 15, pen);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      canvas.drawLine(
        _c + Offset.fromDirection(angle, 22),
        _c + Offset.fromDirection(angle, 29),
        pen,
      );
    }
  }

  /// 便签：一张卡 + 两条横线 + 一条波浪。
  ///
  /// 最后一条画成波浪而不是直线 —— 三条一样长的直线读起来像「加载中」
  /// 的骨架屏，而这里说的是「还没写东西」。
  void _note(Canvas canvas, Paint pen) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: _c, width: 46, height: 54),
        const Radius.circular(8),
      ),
      pen,
    );
    canvas.drawLine(const Offset(48, 50), const Offset(72, 50), pen);
    canvas.drawLine(const Offset(48, 62), const Offset(66, 62), pen);
    canvas.drawPath(
      Path()
        ..moveTo(48, 75)
        ..quadraticBezierTo(54, 69, 60, 75)
        ..quadraticBezierTo(66, 81, 72, 75),
      pen,
    );
  }

  /// 甘特的条：三根长短不一、起点各不相同。
  ///
  /// 等长等起点的话就是三条横线（跟便签撞了）；错开才读得出「排期」。
  void _span(Canvas canvas, Paint pen) {
    const bars = [(38.0, 72.0, 44.0), (48.0, 88.0, 60.0), (32.0, 64.0, 76.0)];
    for (final (left, right, y) in bars) {
      canvas.drawLine(Offset(left, y), Offset(right, y), pen..strokeWidth = 7);
    }
    pen.strokeWidth = _strokeWidth;
  }

  /// 漏斗：一个上宽下窄的口 + 一段细颈。
  void _filtered(Canvas canvas, Paint pen) {
    canvas.drawPath(
      Path()
        ..moveTo(38, 42)
        ..lineTo(82, 42)
        ..lineTo(65, 64)
        ..lineTo(65, 82)
        ..lineTo(55, 76)
        ..lineTo(55, 64)
        ..close(),
      pen,
    );
  }

  /// 空盒子：一个敞口的容器 + 一道盖沿。
  ///
  /// 敞口（上边不封）是「里面没东西」的那一半意思；
  /// 封上就成了一个箱子，读不出空。
  void _box(Canvas canvas, Paint pen) {
    canvas.drawPath(
      Path()
        ..moveTo(38, 52)
        ..lineTo(44, 80)
        ..lineTo(76, 80)
        ..lineTo(82, 52),
      pen,
    );
    canvas.drawLine(const Offset(34, 52), const Offset(86, 52), pen);
  }

  /// 云 + 一道斜杠。
  ///
  /// 斜杠**穿过**云而不是画在旁边：画在旁边是两个物件，
  /// 穿过去才读成「这朵云不通」。
  void _offline(Canvas canvas, Paint pen) {
    // 云 = 两个圆 + 一条圆角底座，**并集之后再描边**。
    //
    // 第一版是手写几段 `arcToPoint` 接起来的，画出来是个说不清的疙瘩：
    // 弧的方向与大小要同时对上，改一个数另一段就崩。
    // 并集把「形状」和「轮廓」分开了 —— 形状用三个谁都画得对的基本图形
    // 摆出来，轮廓交给 `Path.combine`。
    var cloud = Path()
      ..addOval(Rect.fromCircle(center: const Offset(53, 62), radius: 11));
    for (final part in [
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(69, 60), radius: 14)),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(42, 62, 82, 74),
          const Radius.circular(6),
        ),
      ),
    ]) {
      cloud = Path.combine(PathOperation.union, cloud, part);
    }
    canvas.drawPath(cloud, pen);
    canvas.drawLine(const Offset(44, 84), const Offset(80, 44), pen);
  }

  @override
  bool shouldRepaint(_EmptyPainter old) =>
      old.motif != motif || old.blob != blob || old.ink != ink;
}
