# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude Code Best Practices

**Documentation Research**: When implementing any Godot-related feature or solving a problem, ALWAYS use the DeepWiki MCP tool to search the official Godot documentation first. This ensures you follow best practices and use the most appropriate APIs.

Example usage:
- For node-specific questions: Search "godot CharacterBody3D" or "godot Area3D"
- For system features: Search "godot physics" or "godot animation"
- For plugins: Search "terrain3d godot" or relevant addon name

## Project Overview

This is a 3D first-person/third-person action game built with Godot 4.5. The player controls a skeleton mage who can cast spells at zombies in a procedurally generated terrain environment.

## Running the Project

- **Open in Godot Editor**: Open the project in Godot 4.5+ (project.godot)
- **Main Scene**: `main.tscn` is the entry point (configured in project.godot)
- **Run Project**: Press F5 in Godot Editor or use the "Run" button
- **Test Specific Scene**: Press F6 to run the currently open scene

## Core Game Architecture

### Player System (`player.gd`)
The player controller handles both first-person (FP) and third-person (TP) camera modes with smooth transitions.

**Key Components:**
- **Camera System**: Dual-mode camera with orbit controls (middle mouse button), dynamic FOV during sprint, and camera shake on spell impact
- **Movement**: WASD movement with sprint (Shift), jump (Space), and view toggle (V key)
- **Spell Casting**: Left-click to cast spells from `skeleton_mage/Rig/Skeleton3D/SpellSpawn` position
- **Animation States**: Idle, Walking_A, Running_A, Jump_Start, Jump_Idle, Jump_Land, Spellcasting

**Important Details:**
- Uses signal `hit_registered(shake_duration, shake_intensity)` for camera shake
- Meshes are automatically hidden in FP mode (except arms and legs)
- Spell casting prevents movement and plays animation
- Player node must be in the "player" group

### Combat System

**Spell (`spell.gd`):**
- Area3D-based projectile with linear movement
- Deals damage and knockback to zombies on collision
- Triggers camera shake via player signal
- Auto-despawns after lifetime or on hit
- Disables monitoring for 0.05s to prevent immediate player collision

**Zombie (`zombie.gd`):**
- CharacterBody3D with three states: CHASE, IDLE, STUNNED
- AI follows player target until entering AttackZone (IDLE state)
- Health bar visualization using MeshInstance3D scaling
- Knockback system: Flattened horizontal impulse with decay
- Emits `zombie_died(zombie_position)` signal on death
- Must be in "zombie" group for spell targeting
- Requires AnimationPlayer at path `zombie/AnimationPlayer` with animations: `zombie_run/Run`, `zombie_idle/Idle`

### Game Manager (`game_manager.gd`)
Handles zombie spawning and respawning logic.

**Hungarian Comments Note:** This file contains Hungarian comments. Key points:
- Spawns zombies at specified positions
- Listens for `zombie_died` signal to respawn after 1 second delay
- Maintains reference to player via "player" group

### Terrain Generation (`TerrainGenerator.gd`)
Procedural terrain generation system using Perlin noise for organic paths.

**Hungarian Comments Note:** This file is heavily commented in Hungarian. Key concepts:
- Generates a control map (1024x1024) with 4 terrain types: Forest (0), Path (1), Margin (2), Rock/Clearing (3)
- Uses Perlin noise for winding main paths with perpendicular branch paths (dead-ends)
- Outputs debug visualization as `debug_control_map.png`
- Integrates with Terrain3D addon for visual rendering
- Control map uses RGBA channels: R=Path, G=Margin, B=Rock, A=Forest

### Pickup System (`pickup.gd`)
Simple collectible system using Area3D and signals.

## Scene Structure

**Key Scenes:**
- `main.tscn`: Main game scene
- `player.tscn`: Player character with skeleton mage model
- `zombie.tscn`: Enemy zombie character
- `spell.tscn`: Spell projectile with Timer child node
- `terrain_generator.tscn`: Procedural terrain generator node

**Demo Scenes (Reference Only):**
- `demo/Demo.tscn`: Terrain3D demonstration
- `demo/components/Player.tscn`: Alternative player implementation with different controls

## Godot Addons

This project uses three editor plugins (enabled in project.godot):

1. **Terrain3D** (`addons/terrain_3d/`): Advanced terrain system with LOD, painting, and importing tools
2. **Sky 3D** (`addons/sky_3d/`): Dynamic sky and time-of-day system
3. **Proton Scatter** (`addons/proton_scatter/`): Object scattering system for vegetation/props

## Input Mapping

Configured in `project.godot`:
- **Movement**: WASD (ui_left/right/up/down)
- **Jump**: Space
- **Sprint**: Shift
- **Cast Spell**: Left Mouse Button (fire_spell)
- **Toggle View**: V (toggle_view)

## Code Conventions

- **Script Language**: GDScript with `extends` pattern
- **Export Variables**: Used extensively for tweakable parameters
- **Signals**: Used for decoupled communication (zombie death, spell impact, pickup collection)
- **Groups**: Player must be in "player" group, zombies in "zombie" group
- **Comments**: Mix of English and Hungarian; recent commits show standardization toward English

## Asset Organization

- `assets/`: Game assets (exact structure to be determined)
- `terrain_data/`: Terrain3D resource files (.res)
- `demo/assets/models/`: Demo 3D models (rocks, crystals, tunnel)

## Git Workflow

**Main Branch**: `main`
**Current Branch**: `map-generation-test`

**Recent Development:**
- Zombie knockback and impact mechanics
- Camera shake on spell collision
- Player movement and spell casting system
- Terrain generation experiments

## Important Implementation Notes

1. **Node Paths**: The game uses specific node paths for references (e.g., `skeleton_mage/Rig/Skeleton3D/SpellSpawn`). Verify these exist when modifying scene structure.

2. **Timer Nodes**: Spell scene requires a Timer child node named "Timer" for auto-despawn.

3. **AnimationPlayer**: Both player and zombie expect AnimationPlayer nodes at specific paths with specific animation names.

4. **Groups**: Proper group assignment is critical for player-zombie and spell-zombie interactions.

5. **3D Space Coordinates**: The game uses Godot's default 3D coordinate system (Y-up).

6. **Collision Layers**: Ensure proper collision layer configuration for spells to hit zombies but not the player.

7. **Signal Connections**: Several systems rely on signal-based communication. Check `_ready()` functions for `connect()` calls.

## Terrain3D Integration

The procedural terrain generator creates a control map that integrates with the Terrain3D addon. The control map is saved as a PNG for debugging and can be imported into Terrain3D's control map slot.

## Performance Considerations

- Spell projectiles despawn after 3 seconds (configurable lifetime)
- Zombie count managed by game_manager
- Terrain generation happens at initialization
