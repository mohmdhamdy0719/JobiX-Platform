import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design/jobix_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Meaningful parents for replacement navigation. Root tabs have no invented
/// history; exit is confirmed there. Auth redirects remain router-owned.
String? backDestination(Uri uri) {
  final path = uri.path;
  final origin = uri.queryParameters['origin'];
  if (path.startsWith('/builder/')) {
    if (origin == 'review') return '/builder/6';
    if (origin == 'career') return '/career';
    final step = int.tryParse(uri.pathSegments.last) ?? 1;
    return step > 1 ? '/builder/${step - 1}' : '/home';
  }
  if (path.startsWith('/career/')) {
    if (origin == 'personal' && path == '/career/target-role') {
      return '/career/personal';
    }
    return origin == 'review' ? '/builder/6' : '/career';
  }
  if (path == '/resume') return '/career';
  if (path == '/export-history') return '/resume';
  if (path == '/credits') return '/home';
  if (path == '/confirm' || path == '/forgot') return '/auth?mode=login';
  if (path == '/auth' && uri.queryParameters.containsKey('mode')) {
    return '/auth';
  }
  return null;
}

/// Shared by system Back and visible Back controls. Popup routes (dialogs,
/// dropdowns and sheets) are handled by Navigator before this page boundary.
Future<void> requestJobixBack(BuildContext context) async {
  final boundary = context.findAncestorStateOfType<_JobixBackBoundaryState>();
  if (boundary != null) await boundary.back();
}

class JobixBackBoundary extends StatefulWidget {
  const JobixBackBoundary({required this.uri, required this.child, super.key});
  final Uri uri;
  final Widget child;
  @override
  State<JobixBackBoundary> createState() => _JobixBackBoundaryState();
}

class _JobixBackBoundaryState extends State<JobixBackBoundary> {
  final handlers = <Object, FutureOr<void> Function()>{};
  bool handling = false;

  Future<void> back() async {
    if (handling || !mounted) return;
    // Android normally consumes IME Back before popRoute. This also preserves
    // keyboard-first behavior for visible Back buttons and host tests.
    if (MediaQuery.viewInsetsOf(context).bottom > 0 &&
        FocusManager.instance.primaryFocus?.hasFocus == true) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    handling = true;
    try {
      if (handlers.isNotEmpty) {
        await handlers.values.last();
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
      final parent = backDestination(widget.uri);
      if (parent != null) {
        context.go(parent);
        return;
      }
      final copy = AppLocalizations.of(context)!;
      final exit = await showDialog<bool>(
        context: context,
        builder: (context) => JobixAlertDialog(
          title: Text(copy.exitTitle),
          content: Text(copy.exitMessage),
          actions: [
            JobixDialogAction.secondary(
              key: const Key('stay-in-jobix'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(copy.stayAction),
            ),
            JobixDialogAction.destructive(
              key: const Key('exit-jobix'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(copy.exitAction),
            ),
          ],
        ),
      );
      if (exit == true && mounted) await SystemNavigator.pop();
    } finally {
      handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(back());
    },
    child: _BackRegistration(boundary: this, child: widget.child),
  );
}

class _BackRegistration extends InheritedWidget {
  const _BackRegistration({required this.boundary, required super.child});
  final _JobixBackBoundaryState boundary;
  @override
  bool updateShouldNotify(_BackRegistration oldWidget) =>
      boundary != oldWidget.boundary;
}

/// Editors provide a discard-aware override without registering a second
/// PopScope on the same route. Registration owns no controller/provider.
class JobixBackHandler extends StatefulWidget {
  const JobixBackHandler({
    required this.onBack,
    required this.child,
    super.key,
  });
  final FutureOr<void> Function()? onBack;
  final Widget child;
  @override
  State<JobixBackHandler> createState() => _JobixBackHandlerState();
}

class _JobixBackHandlerState extends State<JobixBackHandler> {
  _JobixBackBoundaryState? boundary;
  final token = Object();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<_BackRegistration>()
        ?.boundary;
    if (next != boundary) {
      boundary?.handlers.remove(token);
      boundary = next;
    }
    register();
  }

  void register() {
    if (widget.onBack == null) {
      boundary?.handlers.remove(token);
    } else {
      boundary?.handlers[token] = () => widget.onBack!();
    }
  }

  @override
  void didUpdateWidget(JobixBackHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    register();
  }

  @override
  void dispose() {
    boundary?.handlers.remove(token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
