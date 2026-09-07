/// 入口。**只做 bootstrap，不写业务**（docs/01-architecture/module-map.md §1）。
library;

import 'app.dart';
import 'bootstrap.dart';

void main() => bootstrap(PlanningAssistantApp.new);
