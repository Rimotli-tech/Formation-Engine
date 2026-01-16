import 'package:flutter/material.dart';
import 'player_model.dart';

class FormationEngine extends ChangeNotifier {
  List<Player> players = [];
  String currentFormation = "4-3-3";

  // Default Team Color (Red)
  Color teamColor = const Color.fromARGB(255, 16, 136, 66);

  FormationEngine() {
    calculateFormation("4-3-3"); // Default
  }

  void updateTeamColor(Color newColor) {
    teamColor = newColor;
    notifyListeners();
  }

  void calculateFormation(String input) {
    List<Player> newPlayers = [];

    // 1. Always add the Goalkeeper at Index 0
    newPlayers.add(
      Player(
        index: 0,
        role: "GK",
        position: const Offset(50, 5), // Bottom center (percentage)
      ),
    );

    // 2. Parse Outfield Rows (e.g., "4-4-2" -> [4, 4, 2])
    List<int> rows;
    try {
      rows = input.split('-').map(int.parse).toList();
      // Validate: Must sum to 10
      if (rows.reduce((a, b) => a + b) != 10) throw Exception("Must sum to 10");
    } catch (e) {
      debugPrint("Invalid Formation: $e");
      return;
    }

    int playerIndex = 1;
    // 3. Calculate Coordinates (These act as the TARGET destination)
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      int playersInRow = rows[rowIndex];

      // Calculate Y: Defenders (25%), Midfield (55%), Attack (85%)
      double yPos = 20 + (rowIndex * (70 / (rows.length - 1)));

      for (int i = 0; i < playersInRow; i++) {
        // Calculate X: Space them evenly across 0-100
        double xPos = (100 / (playersInRow + 1)) * (i + 1);

        newPlayers.add(
          Player(
            index: playerIndex,
            role: _getRoleLabel(rowIndex, i, playersInRow, rows.length),
            position: Offset(xPos, yPos),
          ),
        );
        playerIndex++;
      }
    }

    players = newPlayers;
    currentFormation = input;
    notifyListeners();
  }

  // Logic to differentiate "CB" from "LB" based on their X position
  String _getRoleLabel(int row, int pos, int totalInRow, int totalRows) {
    if (row == 0) return pos == 0 || pos == totalInRow - 1 ? "FB" : "CB";
    if (row == totalRows - 1) return "ST";
    return "MID";
  }
}
