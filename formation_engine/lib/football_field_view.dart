import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rive/rive.dart' as rive;
import 'formation_engine.dart';
import 'dart:math';

const String kViewModelName = 'TacticsVMInstance';

// Properties
const String kPropX = 'posX';
const String kPropY = 'posY';
const String kPropTargetX = 'targetX';
const String kPropTargetY = 'targetY';
const String kPropRole = 'role';
const String kPropTeamColor = 'teamColor';
const String kConnectStatusString = 'connectionStatus';

class FootballFieldView extends StatefulWidget {
  const FootballFieldView({super.key});

  @override
  State<FootballFieldView> createState() => _FootballFieldViewState();
}

class _FootballFieldViewState extends State<FootballFieldView>
    with SingleTickerProviderStateMixin {
  final FormationEngine _formationEngine = FormationEngine();

  // Rive State
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModelInstance;

  // Animation
  late Ticker _ticker;
  final List<Offset> _currentPositions = List.generate(
    11,
    (_) => const Offset(0, 0),
  );

  final double _artboardWidth = 1549.0;
  final double _artboardHeight = 911.0;

  late final fileLoader = rive.FileLoader.fromAsset(
    "assets/tactics_board_V23.riv",
    riveFactory: rive.Factory.rive,
  );

  @override
  void initState() {
    super.initState();
    _formationEngine.addListener(_onFormationChanged);
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _formationEngine.removeListener(_onFormationChanged);
    _formationEngine.dispose();
    _viewModelInstance?.dispose();
    fileLoader.dispose();
    super.dispose();
  }

  void _onFormationChanged() {
    if (!_ticker.isActive) _ticker.start();

    if (_viewModelInstance != null) {
      final flutterPlayers = _formationEngine.players;
      for (int i = 0; i < flutterPlayers.length; i++) {
        final playerVM = _viewModelInstance!.viewModel('player${i + 1}');
        if (playerVM != null) {
          playerVM.string(kPropRole)?.value = flutterPlayers[i].role;
          playerVM.color(kPropTeamColor)?.value = _formationEngine.teamColor;
        }
      }
    }
  }

  void _onRiveLoaded(rive.RiveWidgetController controller) {
    if (_controller == controller) return;
    _controller = controller;

    try {
      _viewModelInstance = controller.dataBind(
        rive.DataBind.byName(kViewModelName),
      );

      _viewModelInstance?.string(kConnectStatusString)?.value =
          'Connection Active';
      _snapToFormation();
      _ticker.start();
      setState(() {});
    } catch (e) {
      debugPrint('Rive Binding Error: $e');
    }
  }

  void _snapToFormation() {
    if (_viewModelInstance == null) return;
    final flutterPlayers = _formationEngine.players;

    for (int i = 0; i < flutterPlayers.length; i++) {
      Offset target = _convertToArtboard(flutterPlayers[i].position);
      _currentPositions[i] = target;

      final playerVM = _viewModelInstance!.viewModel('player${i + 1}');
      if (playerVM != null) {
        playerVM.number(kPropX)?.value = target.dx;
        playerVM.number(kPropY)?.value = target.dy;
        playerVM.color(kPropTeamColor)?.value = _formationEngine.teamColor;
        playerVM.string(kPropRole)?.value = flutterPlayers[i].role;
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_viewModelInstance == null) return;

    final flutterPlayers = _formationEngine.players;
    const double speed = 5.0;
    const double dt = 0.016;
    final double lerpFactor = 1 - exp(-speed * dt);
    const double threshold = 0.5;

    for (int i = 0; i < flutterPlayers.length; i++) {
      Offset target = _convertToArtboard(flutterPlayers[i].position);
      Offset current = _currentPositions[i];
      double dist = (target - current).distance;

      if (dist > threshold) {
        double newX = current.dx + (target.dx - current.dx) * lerpFactor;
        double newY = current.dy + (target.dy - current.dy) * lerpFactor;

        _currentPositions[i] = Offset(newX, newY);

        final playerVM = _viewModelInstance!.viewModel('player${i + 1}');
        if (playerVM != null) {
          playerVM.number(kPropX)?.value = newX;
          playerVM.number(kPropY)?.value = newY;
          playerVM.number(kPropTargetX)?.value = target.dx;
          playerVM.number(kPropTargetY)?.value = target.dy;
        }
      } else {
        if (dist > 0) {
          _currentPositions[i] = target;
          final playerVM = _viewModelInstance!.viewModel('player${i + 1}');
          playerVM?.number(kPropX)?.value = target.dx;
          playerVM?.number(kPropY)?.value = target.dy;
        }
      }
    }
  }

  Offset _convertToArtboard(Offset enginePos) {
    final double offsetX = -(_artboardWidth * 0.75) * 0.5;
    final double offsetY = -_artboardHeight * 0.5;
    double depth = enginePos.dy.clamp(0.0, 100.0);
    double width = enginePos.dx.clamp(0.0, 100.0);

    double riveX = (1 - (depth / 100)) * (_artboardWidth * 0.75);
    double riveY = (width / 100) * _artboardHeight;
    return Offset(riveX + offsetX, riveY + offsetY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 11, 13, 15),
      // appBar: AppBar(
      //   title: const Text("Formation Engine"),
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      // ),
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
            child: Text(
              "Rive Runtime via Flutter",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
