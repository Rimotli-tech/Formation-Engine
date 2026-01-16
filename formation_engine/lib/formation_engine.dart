import 'package:flutter/material.dart';
import 'player_model.dart';

class FormationEngine extends ChangeNotifier {
  List<Player> players = [];
  String currentFormation = "4-3-3";
  Color teamColor = const Color.fromARGB(255, 16, 136, 66);

  FormationEngine() {
    calculateFormation("4-3-3");
  }

  void updateTeamColor(Color newColor) {
    teamColor = newColor;
    notifyListeners();
  }

  void calculateFormation(String input) {
    List<Player> newPlayers = [];

    // 1. Goalkeeper (Index 0) - Positioned at 5% Depth (Goal Line)
    newPlayers.add(Player(index: 0, role: "GK", position: const Offset(50, 5)));

    // 2. Parse Rows
    List<int> rows;
    try {
      rows = input.split('-').map(int.parse).toList();
      if (rows.reduce((a, b) => a + b) != 10) throw Exception("Must sum to 10");
    } catch (e) {
      debugPrint("Invalid Formation: $e");
      return;
    }

    int playerIndex = 1;

    // 3. Calculate Coordinates (User's Logic)
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      int playersInRow = rows[rowIndex];

      // Calculate Y (Depth): Defenders (20%), Midfield (~50%), Attack (90%)
      double yPos = 20 + (rowIndex * (70 / (rows.length - 1)));

      for (int i = 0; i < playersInRow; i++) {
        // Calculate X (Width): Space them evenly across 0-100
        double xPos = (100 / (playersInRow + 1)) * (i + 1);

        // Determine specific role
        String role = _getRoleLabel(rowIndex, i, playersInRow, rows.length);

        // Apply Positional Nuances to the base grid position
        Offset finalPos = _applyPositionalNuance(Offset(xPos, yPos), role);

        newPlayers.add(
          Player(index: playerIndex, role: role, position: finalPos),
        );
        playerIndex++;
      }
    }

    players = newPlayers;
    currentFormation = input;
    notifyListeners();
  }

  /// Nudges players based on role (dx=Width, dy=Depth)
  Offset _applyPositionalNuance(Offset base, String role) {
    double width = base.dx;
    double depth = base.dy;

    switch (role) {
      case "LB":
      case "RB":
      case "LWB":
      case "RWB":
        depth += 15; // Push fullbacks forward (Leftward)
        break;
      case "DM":
        depth -= 5; // Drop DM deeper
        break;
      case "AM":
        depth += 5; // Push AM higher
        break;
      case "LW":
      case "RW":
        depth += 10; // Wingers push high
        break;
    }
    return Offset(width, depth);
  }

  /// Returns specific roles (LB, RB, CM, ST) instead of generic ones
  String _getRoleLabel(int row, int pos, int totalInRow, int totalRows) {
    // Defenders
    if (row == 0) {
      if (totalInRow == 3) return "CB";
      if (totalInRow == 5) {
        return (pos == 0)
            ? "RWB"
            : (pos == totalInRow - 1)
            ? "LWB"
            : "CB";
      }
      // 4-man backline: Pos 0 is Top (Right), Pos Last is Bottom (Left)
      if (pos == 0) return "RB";
      if (pos == totalInRow - 1) return "LB";
      return "CB";
    }

    // Attackers
    if (row == totalRows - 1) {
      if (totalInRow == 3) {
        return (pos == 0)
            ? "RW"
            : (pos == totalInRow - 1)
            ? "LW"
            : "ST";
      }
      return "ST";
    }

    // Midfielders
    bool isDeepMid = row == 1 && totalRows > 3;
    bool isHighMid = row == totalRows - 2 && totalRows > 3;
    if (isDeepMid) return "DM";
    if (isHighMid) return "AM";

    if (totalInRow >= 4) {
      if (pos == 0) return "RM";
      if (pos == totalInRow - 1) return "LM";
    }
    return "CM";
  }
}
