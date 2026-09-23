import 'package:flutter/widgets.dart';

class KeepAliveScaffold extends StatefulWidget {
  const KeepAliveScaffold({
    required this.child,
  });

  final Widget child;

  @override
  State<KeepAliveScaffold> createState() => KeepAliveScaffoldState(child);
}

class KeepAliveScaffoldState extends State<KeepAliveScaffold>
    with AutomaticKeepAliveClientMixin {
  final Widget child;

  KeepAliveScaffoldState(this.child);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return child;
  }
}
