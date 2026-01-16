import 'package:flutter/material.dart';

class Player {
  final int index;
  final String role; // e.g., "GK", "CB", "ST"
  Offset position;
  //Color teamColor = Color.fromARGB(255, 243, 47, 33);

  Player({
    required this.index,
    required this.role,
    required this.position,
    //required this.teamColor,
  });
}
