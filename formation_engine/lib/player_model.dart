import 'package:flutter/material.dart';

class Player {
  final int index;
  final String role; // e.g., "GK", "CB", "ST"
  Offset position;

  Player({
    required this.index,
    required this.role,
    required this.position,
  });
}