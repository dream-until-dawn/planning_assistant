/// 轻提示（design-system §8.3）。**全项目发提示的唯一入口。**
///
/// ## 为什么必须收成一个函数
///
/// 这段话原本以注释的形式抄在四个地方：
///
/// > Flutter 的 `SnackBar` 里有一行：`persist = persist ?? action != null`
/// > —— **带 action 的提示默认永不自动消失**，等用户去点。
/// > 而我们每一条提示都带「撤销」，于是全都是永久的：`duration` 照样
/// > 设了，计时器也照样起，但回调第一句是 `if (snackBar.persist) return;`。
///
/// 那正是用户报的第 ② 条：「下方的轻提示永远不会消失」—— 屏幕底部被
/// 一条陈旧提示长期占住，它上面的「撤销」还连着一个早就过期的闭包，
/// 后面每一条新提示都排在它后面出不来。
///
/// 修的时候四处各加了一行 `persist: false`。**第五处呢？**
/// 抄第五遍的人不会知道有这一行要抄 —— 默认值的坑就是这样：
/// 不写它，代码看着完全正常。所以入口收成一个，
/// 另有一条架构守卫盯着「别处不许直接 new SnackBar」。
library;

import 'package:flutter/material.dart';

/// 弹一条提示，可带「撤销」。
///
/// [messenger] 由调用方**在 await 之前**取好（`ScaffoldMessenger.of(context)`）
/// —— 异步之后 context 可能已经不在树上了。允许为 null 是为了让
/// 滑动那条路上「组件已经拆了」的情形不必在调用点写判空。
void showUndoSnackBar(
  ScaffoldMessengerState? messenger,
  String message, {
  VoidCallback? onUndo,
  String undoLabel = '撤销',
}) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // 见上面那段。**这一行是这个函数存在的理由。**
        persist: false,
        action: onUndo == null
            ? null
            // Key 挂在 action 上没用（它不是 widget 树里的一个节点），
            // 所以测试用 content 的文案定位整条提示，撤销按钮由 label 找。
            : SnackBarAction(label: undoLabel, onPressed: onUndo),
      ),
    );
}
