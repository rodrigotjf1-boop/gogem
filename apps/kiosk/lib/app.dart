import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme/gogem_theme.dart';

class GogemKioskApp extends StatelessWidget {
  const GogemKioskApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'GoGeM',
        debugShowCheckedModeBanner: false,
        theme: gogemTheme(),
        routerConfig: router,
      );
}
