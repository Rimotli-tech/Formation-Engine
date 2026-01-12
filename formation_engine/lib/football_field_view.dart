import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'formation_engine.dart';

// -----------------------------------------------------------------------------
// CONFIGURATION: Update these names to match your Rive File exactly!
// -----------------------------------------------------------------------------
const String kViewModelName = 'Instance'; // The name of the VM in Rive
const String kPlayerListName = 'Players';     // The name of the List Property
const String kItemViewModelName = 'Player';   // Name of the individual item VM (for creating new ones)
const String kItemViewModelTestString = 'StringTester';
const String kPropX = 'posX';                 // Number property for X position (0-100)
const String kPropY = 'posY';                 // Number property for Y position (0-100)
const String kPropRole = 'role';              // String property for Role (e.g. "GK", "ST")
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

  // File Loader with Rive Factory (Required for Data Binding)
  late final fileLoader = rive.FileLoader.fromAsset(
    "assets/tactics_board_V2.riv",
    riveFactory: rive.Factory.rive, // [cite: 162] Use Factory.rive for C++ features
  );

  @override
  void initState() {
    super.initState();
    // Listen to formation changes to update Rive
    _formationEngine.addListener(_syncFormation);
  }

  @override
  void dispose() {
    _formationEngine.removeListener(_syncFormation);
    _formationEngine.dispose();
    _viewModelInstance?.dispose(); // [cite: 186] Dispose VM instance
    fileLoader.dispose();
    super.dispose();
  }

  /// Establishes the link between Flutter and the Rive View Model
  void _onRiveLoaded(rive.RiveWidgetController controller) {
    if (_controller == controller) return; // Prevent re-binding
    _controller = controller;

    try {
    // 1. Bind to the View Model
    _viewModelInstance = controller.dataBind(rive.DataBind.byName(kViewModelName));

    // --- ADD THE TEST CODE HERE ---
    final testProp = _viewModelInstance?.string(kItemViewModelTestString);
    if (testProp != null) {
      testProp.value = "Connection Verified!"; //
      print("Test String Property Set Successfully.");
    }
    // ------------------------------

    _syncFormation();
    setState(() {}); 
  } catch (e) {
    debugPrint('Rive Binding Error: $e');
  }

    try {
      // 1. Bind to the View Model by name [cite: 178]
      _viewModelInstance = controller.dataBind(rive.DataBind.byName(kViewModelName));

      // 2. Initial Sync
      _syncFormation();
      
      setState(() {}); // Rebuild to show controls if needed
    } catch (e) {
      debugPrint('Rive Binding Error: $e');
    }
  }

  /// Syncs the Flutter FormationEngine data to the Rive List Property
  void _syncFormation() {
    if (_viewModelInstance == null || _controller == null) return;

    // A. Access the List Property dynamically 
    // We use 'final' here instead of an explicit type because the SDK 
    // does not export the specific List class name.
    final rivePlayersList = _viewModelInstance!.list(kPlayerListName);
    
    if (rivePlayersList == null) return;

    final flutterPlayers = _formationEngine.players;

    // B. Adjust List Size: Add/Remove Rive items to match Flutter count
    while (rivePlayersList.length < flutterPlayers.length) {
      // Create a new Player VM instance (using the item name from Editor)
      final newItem = _controller!.file.viewModelByName(kItemViewModelName)?.createInstance();
      if (newItem != null) {
        rivePlayersList.add(newItem); //  Add instance to list
      } else {
        break; // Stop if we can't create items
      }
    }
    while (rivePlayersList.length > flutterPlayers.length) {
      rivePlayersList.removeAt(rivePlayersList.length - 1); //  Remove instance
    }

    // C. Update Properties for each player
    for (int i = 0; i < flutterPlayers.length; i++) {
      final player = flutterPlayers[i];
      final riveItem = rivePlayersList[i]; //  Access by index

      // Update X Position
      final xProp = riveItem.number(kPropX); 
      if (xProp != null) xProp.value = player.position.dx; // [cite: 9] Update Number

      // Update Y Position
      final yProp = riveItem.number(kPropY);
      if (yProp != null) yProp.value = player.position.dy;

      // Update Role Text
      final roleProp = riveItem.string(kPropRole);
      if (roleProp != null) roleProp.value = player.role; // [cite: 10] Update String
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
              fileLoader: fileLoader,
              builder: (context, state) => switch (state) {
                rive.RiveLoading() => const Center(child: CircularProgressIndicator()),
                rive.RiveFailed() => Center(child: Text(state.error.toString())),
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
                      // Ensure we use the Rive Renderer for data binding features
                      //useSharedTexture: true, 
                    );
                  }
                ),
              },
            ),
          ),
          
          // Debug/Info Area
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            child: Text(
              "Current Formation: ${_formationEngine.currentFormation}",
              style: const TextStyle(color: Colors.white70),
            ),
          )
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
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
        checkmarkColor: Colors.white,
      ),
    );
  }
}