import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'formation_engine.dart';

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

class _FootballFieldViewState extends State<FootballFieldView> {
  // 1. Initialize the Engine
  final FormationEngine _formationEngine = FormationEngine();

  // Rive State References
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModelInstance;

  // Track if this is the first load to snap positions instead of animating
  bool _isFirstLoad = true;

  // File Loader
  late final fileLoader = rive.FileLoader.fromAsset(
    "assets/tactics_board_V19.riv",
    riveFactory: rive.Factory.rive, // Required for C++ features
  );

  @override
  void initState() {
    super.initState();
    _formationEngine.addListener(_syncFormation);
  }

  @override
  void dispose() {
    _formationEngine.removeListener(_syncFormation);
    _formationEngine.dispose();
    _viewModelInstance?.dispose(); // Always dispose VM instances
    fileLoader.dispose();
    super.dispose();
  }

  /// Establishes the link between Flutter and the Rive View Model
  void _onRiveLoaded(rive.RiveWidgetController controller) {
    if (_controller == controller) return;
    _controller = controller;

    try {
      // 1. Bind to the Main View Model
      _viewModelInstance = controller.dataBind(
        rive.DataBind.byName(kViewModelName),
      );

      // 2. Initial Sync
      _syncFormation();
      _connectionTestString();
      setState(() {});
    } catch (e) {
      debugPrint('Rive Binding Error: $e');
    }
  }

  void _connectionTestString() {
    final connectStatusVM = _viewModelInstance?.string(kConnectStatusString);
    if (connectStatusVM != null) {
      connectStatusVM.value = 'Connection Active';
    }
  }

  void _syncFormation() {
    if (_viewModelInstance == null) return;

    final flutterPlayers = _formationEngine.players;

    const double artboardWidth = 1549.0;
    const double artboardHeight = 911.0;

    for (int i = 0; i < flutterPlayers.length; i++) {
      final player = flutterPlayers[i];

      final playerVM = _viewModelInstance!.viewModel('player${i + 1}');

      if (playerVM != null) {
        double riveTargetX = (50 - player.position.dy) / 100 * artboardWidth;
        double riveTargetY = (player.position.dx - 50) / 100 * artboardHeight;

        playerVM.number(kPropTargetX)?.value = riveTargetX;
        playerVM.number(kPropTargetY)?.value = riveTargetY;
        debugPrint(riveTargetY.toString());

        if (_isFirstLoad) {
          playerVM.number(kPropX)?.value = riveTargetX;
          playerVM.number(kPropY)?.value = riveTargetY;
        }

        final teamColorProp = playerVM.color(kPropTeamColor);
        if (teamColorProp != null) {
          teamColorProp.value = _formationEngine.teamColor;
        }

        playerVM.string(kPropRole)?.value = player.role;
      }
    }

    // After first sync, disable the "teleport" flag
    if (_isFirstLoad) {
      _isFirstLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 37, 51, 77),
      appBar: AppBar(
        title: const Text("Tactics Board"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // -------------------------------------------------------
          // 1. Formation Controls
          // -------------------------------------------------------
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFormationBtn("4-4-2"),
                _buildFormationBtn("4-3-3"),
                _buildFormationBtn("3-5-2"),
                _buildFormationBtn("5-3-2"),
              ],
            ),
          ),

          // -------------------------------------------------------
          // 2. Color Controls
          // -------------------------------------------------------
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  "Team Color: ",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 10),
                _buildColorBtn(const Color.fromARGB(255, 243, 47, 33)), // Red
                _buildColorBtn(Colors.blueAccent),
                _buildColorBtn(Colors.white),
                _buildColorBtn(Colors.amber),
                _buildColorBtn(Colors.black),
              ],
            ),
          ),

          // -------------------------------------------------------
          // 3. Rive Board
          // -------------------------------------------------------
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
                    // Trigger binding logic once loaded
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _onRiveLoaded(state.controller);
                    });

                    return rive.RiveWidget(
                      controller: state.controller,
                      fit: rive.Fit.contain,
                      layoutScaleFactor: 0.3,
                      alignment: Alignment.topCenter,
                    );
                  },
                ),
              },
            ),
          ),

          // -------------------------------------------------------
          // 4. Debug Info
          // -------------------------------------------------------
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              "Formation: ${_formationEngine.currentFormation}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationBtn(String formation) {
    bool isSelected = _formationEngine.currentFormation == formation;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(formation),
        selected: isSelected,
        onSelected: (_) => _formationEngine.calculateFormation(formation),
        backgroundColor: Colors.white10,
        selectedColor: Colors.blueAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildColorBtn(Color color) {
    bool isSelected = _formationEngine.teamColor == color;
    return GestureDetector(
      onTap: () => _formationEngine.updateTeamColor(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.greenAccent, width: 3)
              : Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}
