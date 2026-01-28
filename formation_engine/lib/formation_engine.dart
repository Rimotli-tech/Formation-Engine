import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

const String kViewModelName = 'TacticsVMInstance';
const String kConnectStatusString = 'connectionStatus';

/// Renamed from FootballFieldView to FormationEngine
class FormationEngine extends StatefulWidget {
  const FormationEngine({super.key});

  @override
  State<FormationEngine> createState() => _FormationEngineState();
}

class _FormationEngineState extends State<FormationEngine> {
  // Rive State
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModelInstance;

  late final fileLoader = rive.FileLoader.fromAsset(
    "assets/tactics_board_V23.riv",
    riveFactory: rive.Factory.rive,
  );

  @override
  void dispose() {
    _viewModelInstance?.dispose();
    fileLoader.dispose();
    super.dispose();
  }

  /// Sets up initial data binding once the Rive file is loaded.
  /// Logic for player positions and movement is now handled internally by Rive Scripting.
  void _onRiveLoaded(rive.RiveWidgetController controller) {
    if (_controller == controller) return;
    _controller = controller;

    try {
      _viewModelInstance = controller.dataBind(
        rive.DataBind.byName(kViewModelName),
      );

      // Simple handshake to confirm Flutter -> Rive communication is active
      _viewModelInstance?.string(kConnectStatusString)?.value =
          'Connection Active';

      setState(() {});
    } catch (e) {
      debugPrint('Rive Binding Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 11, 13, 15),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Image.asset('Formation_Engine_Logo.png'),
            ),
          ),
          Expanded(
            child: rive.RiveWidgetBuilder(
              stateMachineSelector: rive.StateMachineSelector.byName(
                'State Machine 1',
              ),
              fileLoader: fileLoader,
              builder: (context, state) => switch (state) {
                rive.RiveLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                rive.RiveFailed() => Center(
                  child: Text(state.error.toString()),
                ),
                rive.RiveLoaded() => Builder(
                  builder: (context) {
                    // Schedule the binding setup after the widget is built
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _onRiveLoaded(state.controller);
                    });
                    return rive.RiveWidget(
                      controller: state.controller,
                      fit: rive.Fit.contain,
                      layoutScaleFactor: 1,
                      alignment: Alignment.topCenter,
                    );
                  },
                ),
              },
            ),
          ),
          Container(
            height: 80,
            alignment: Alignment.center,
            child: const Text(
              "Rive Runtime via Flutter (Scripting Enabled)",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
