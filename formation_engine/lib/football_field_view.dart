import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'formation_engine.dart';

// -----------------------------------------------------------------------------
// CONFIGURATION: Update these names to match your Rive File exactly!
// -----------------------------------------------------------------------------
const String kViewModelName =
    'TacticsVMInstance'; // Name of the Main VM Instance
const String kPropX = 'posX'; // Number property inside PlayerVM
const String kPropY = 'posY'; // Number property inside PlayerVM
const String kPropRole = 'role'; // String property for Role
const String kTestString = 'StringTester'; //...........Connecting or not

// Note: List constants are removed as we now access instances directly
// -----------------------------------------------------------------------------

class FootballFieldView extends StatefulWidget {
  const FootballFieldView({super.key});

  @override
  State<FootballFieldView> createState() => _FootballFieldViewState();
}

class _FootballFieldViewState extends State<FootballFieldView> {
  final GlobalKey _rivePanelKey = GlobalKey();

  // 1. Initialize the Engine
  final FormationEngine _formationEngine = FormationEngine();

  // Rive State References
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _viewModelInstance;

  // File Loader
  late final fileLoader = rive.FileLoader.fromAsset(
    "assets/tactics_board_V9.riv",
    riveFactory: rive.Factory.rive, // Required for C++ features
  );

  //Debug Scanner

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

      //Test String Binding
      final testStringVM = _viewModelInstance!.string(kTestString);

      if (testStringVM != null) {
        testStringVM.value = "UPDATED!"; //
      }

      //Position player hard code test
      final player1VM = _viewModelInstance!.viewModel('Player 2');

      if (player1VM != null) {
        player1VM.number(kPropX)?.value = 296; // Hard-coded X
        player1VM.number(kPropY)?.value = 7.0; // Hard-coded Y
        final colorProp = player1VM.color('teamColor');
        if (colorProp != null) {
          colorProp.value = const Color.fromARGB(255, 44, 2, 230);
        }
      }

      // 2. Initial Sync
      _syncFormation();
      setState(() {});
    } catch (e) {
      debugPrint('Rive Binding Error: $e');
    }
  }

  void _syncFormation() {
    print('Sync formation is running');
    if (_viewModelInstance == null) return;

    final flutterPlayers = _formationEngine.players;

    for (int i = 0; i < flutterPlayers.length; i++) {
      final player = flutterPlayers[i];

      final playerVM = _viewModelInstance!.viewModel('player_${i + 1}');

      if (playerVM != null) {
        playerVM.number(kPropX)?.value = player.position.dx; //
        playerVM.number(kPropY)?.value = player.position.dy;

        // Update Role (if you added this property to the PlayerVM)
        playerVM.string(kPropRole)?.value = player.role; //
      }
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
          // Formation Controls
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

          // Rive Board
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
                      layoutScaleFactor: 0.3, // Adjust as needed
                      alignment: Alignment.topCenter,
                    );
                  },
                ),
              },
            ),
          ),

          // Debug Info
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            child: Text(
              "Current Formation: ${_formationEngine.currentFormation}",
              style: const TextStyle(color: Colors.white70),
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
      ),
    );
  }
}
