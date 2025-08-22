// This file defines a simple 2D editor using FlameGame
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Buildcade',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const EditorHomePage(),
    );
  }
}

/// Main game logic for shape editor
/// Manages objects, selection, grid, and camera zoom
class EditorGame extends FlameGame {
  final math.Random _rand = math.Random();
  late GridBackground _grid;

  PositionComponent? _selected;

  PositionComponent? get selected => _selected;
  List<PositionComponent> get instances =>
      children.whereType<PositionComponent>().where((c) => c != _grid).toList();

  /// Updates position of the selected object
  void updateSelectedPosition(double x, double y) {
    final s = _selected;
    if (s == null) return;
    s.position = Vector2(x, y);
  }

  /// Changes size of the selected object (width/height or radius)
  void updateSelectedSize(double size) {
    final s = _selected;
    if (s is EditorRect) {
      s.setSize(size);
    } else if (s is EditorCircle) {
      s.setRadius(size / 2);
    }
  }

  /// Changes color of the selected object
  void updateSelectedColor(Color color) {
    final s = _selected;
    if (s is EditorRect) {
      s.setFillColor(color);
    } else if (s is EditorCircle) {
      s.setFillColor(color);
    }
  }

  /// Adjusts rendering order of shapes
  void bringToFront(PositionComponent c) {
    final maxP = instances.isEmpty
        ? 0
        : instances.map((e) => e.priority).reduce((a, b) => a > b ? a : b);
    c.priority = maxP + 1;
  }

  /// Adjusts rendering order of shapes
  void sendToBack(PositionComponent c) {
    final minP = instances.isEmpty
        ? 0
        : instances.map((e) => e.priority).reduce((a, b) => a < b ? a : b);
    c.priority = minP - 1;
  }

  bool gridVisible = true;
  bool snapToGrid = false;
  double gridSize = 32;

  @override
  Color backgroundColor() => const Color(0xFF121417);

  void toggleGrid() {
    gridVisible = !gridVisible;
    _grid.visible = gridVisible;
  }

  void toggleSnap() {
    snapToGrid = !snapToGrid;
  }

  void setGridSize(double size) {
    gridSize = size.clamp(4, 256);
    _grid.cellSize = gridSize;
  }

  /// Selects the given shape and highlights it
  void select(PositionComponent? c) {
    // clear previous
    if (_selected is SelectableMixin) {
      (_selected as SelectableMixin).selected = false;
    }
    _selected = c;
    if (_selected is SelectableMixin) {
      (_selected as SelectableMixin).selected = true;
    }
  }

  void deleteSelected() {
    _selected?.removeFromParent();
    _selected = null;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder
      ..anchor = Anchor.center
      ..zoom = 1.0;

    // Draw a light grid so placement feels guided
    _grid = GridBackground(cellSize: gridSize, color: const Color(0x33FFFFFF))
      ..visible = gridVisible;
    add(_grid);
  }

  /// Adds a rectangular shape to the canvas
  void addBox({Vector2? position, Color color = Colors.blueAccent}) {
    final sz = 64.0;
    final pos = position ?? (canvasSize / 2) - Vector2.all(sz / 2);
    add(EditorRect(position: pos, size: Vector2.all(sz), color: color));
  }

  /// Adds a circular shape to the canvas
  void addCircle({Vector2? position, Color color = Colors.orange}) {
    final radius = 32.0; // radius is a double, not a Vector2
    final pos = position ?? (canvasSize / 2) - Vector2.all(radius);
    add(EditorCircle(position: pos, radius: radius, color: color));
  }

  void addRandom() {
    // quick helper to sprinkle shapes
    final x = _rand.nextDouble() * (canvasSize.x - 64);
    final y = _rand.nextDouble() * (canvasSize.y - 64);
    if (_rand.nextBool()) {
      addBox(
        position: Vector2(x, y),
        color: Colors.blueAccent.withOpacity(0.8),
      );
    } else {
      addCircle(position: Vector2(x, y), color: Colors.orange.withOpacity(0.9));
    }
  }

  void clearScene() {
    // Keep the grid, remove other components
    final toRemove = children
        .whereType<PositionComponent>()
        .where((c) => c != _grid)
        .toList();
    for (final c in toRemove) {
      c.removeFromParent();
    }
  }

  void setZoom(double value) {
    camera.viewfinder.zoom = value.clamp(0.2, 5.0);
  }

  double get zoom => camera.viewfinder.zoom;

  void pauseGame() => pauseEngine();
  void resumeGame() => resumeEngine();
}

mixin SelectableMixin on PositionComponent {
  bool selected = false;
}

/// A simple grid painter component for the editor background
class GridBackground extends Component {
  GridBackground({required this.cellSize, required this.color});
  double cellSize;
  final Color color;
  bool visible = true;

  /// Draws the grid lines in the background
  /// Highlights every 8th line for better spacing visibility
  @override
  void render(Canvas canvas) {
    if (!visible) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final size = (findGame() as FlameGame).canvasSize;

    for (double x = 0; x <= size.x; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), paint);
    }
    for (double y = 0; y <= size.y; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), paint);
    }

    // Emphasize every 8th line
    final accent = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.25;
    for (double x = 0, i = 0; x <= size.x; x += cellSize, i++) {
      if (i % 8 == 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.y), accent);
      }
    }
    for (double y = 0, i = 0; y <= size.y; y += cellSize, i++) {
      if (i % 8 == 0) {
        canvas.drawLine(Offset(0, y), Offset(size.x, y), accent);
      }
    }
  }
}

class EditorRect extends RectangleComponent
    with TapCallbacks, DragCallbacks, SelectableMixin {
  EditorRect({
    required Vector2 position,
    required Vector2 size,
    required Color color,
  }) : _fill = Paint()..color = color,
       super(position: position, size: size, anchor: Anchor.topLeft);

  final Paint _fill;

  void setFillColor(Color color) {
    _fill.color = color;
    paint = _fill;
  }

  void setSize(double edge) {
    size = Vector2.all(edge);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (selected) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00D1FF);
      canvas.drawRect(Offset.zero & size.toSize(), stroke);
      // Draw resize handle(s)
      const double handleSize = 10;
      final Paint handlePaint = Paint()..color = Colors.white;
      final List<Offset> handles = [
        Offset(size.x, size.y), // bottom-right corner
      ];
      for (final handle in handles) {
        canvas.drawRect(
          Rect.fromCenter(
            center: handle,
            width: handleSize,
            height: handleSize,
          ),
          handlePaint,
        );
      }
    }
  }

  @override
  Future<void> onLoad() async {
    paint = _fill;
    await super.onLoad();
  }

  /// Handle tap to select this shape
  @override
  void onTapDown(TapDownEvent event) {
    (findGame() as EditorGame).select(this);
    event.handled = true;
  }

  /// Drag handler — moves shape and optionally snaps to grid
  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
    final g = (findGame() as EditorGame);
    if (g.snapToGrid) {
      final s = g.gridSize;
      position = Vector2(
        (position.x / s).roundToDouble() * s,
        (position.y / s).roundToDouble() * s,
      );
    }
  }
}

class EditorCircle extends CircleComponent
    with TapCallbacks, DragCallbacks, SelectableMixin {
  EditorCircle({
    required Vector2 position,
    required double radius,
    required Color color,
  }) : _fill = Paint()..color = color,
       super(position: position, radius: radius, anchor: Anchor.topLeft);

  final Paint _fill;

  void setFillColor(Color color) {
    _fill.color = color;
    paint = _fill;
  }

  void setRadius(double r) {
    radius = r;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (selected) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00D1FF);
      canvas.drawCircle(Offset(radius, radius), radius, stroke);
      // Draw resize handle
      const double handleSize = 10;
      final Paint handlePaint = Paint()..color = Colors.white;
      final Offset handle = Offset(radius * 2, radius); // edge point
      canvas.drawRect(
        Rect.fromCenter(center: handle, width: handleSize, height: handleSize),
        handlePaint,
      );
    }
  }

  @override
  Future<void> onLoad() async {
    paint = _fill;
    await super.onLoad();
  }

  /// Handle tap to select this shape
  @override
  void onTapDown(TapDownEvent event) {
    (findGame() as EditorGame).select(this);
    event.handled = true;
  }

  /// Drag handler — moves shape and optionally snaps to grid
  @override
  void onDragUpdate(DragUpdateEvent event) {
    position += event.localDelta;
    final g = (findGame() as EditorGame);
    if (g.snapToGrid) {
      final s = g.gridSize;
      position = Vector2(
        (position.x / s).roundToDouble() * s,
        (position.y / s).roundToDouble() * s,
      );
    }
  }
}

class EditorHomePage extends StatefulWidget {
  const EditorHomePage({super.key});

  @override
  State<EditorHomePage> createState() => _EditorHomePageState();
}

class _EditorHomePageState extends State<EditorHomePage> {
  late final EditorGame _game;
  bool _playing = true;
  double _zoom = 1.0;

  /// Opens modal sheet for adding new shapes
  void _openObjectsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Objects',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          _game.addBox();
                          Navigator.pop(ctx);
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square_rounded),
                            SizedBox(width: 8),
                            Text('Add Box'),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          _game.addCircle();
                          Navigator.pop(ctx);
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle),
                            SizedBox(width: 8),
                            Text('Add Circle'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens modal sheet for editing selected shape's properties
  void _openPropertiesSheet() {
    final sel = _game.selected;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            return SafeArea(
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Properties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (sel == null)
                        const Text('No selection')
                      else ...[
                        Row(
                          children: [
                            const Text('Position'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: sel.position.x.toStringAsFixed(1),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  prefixText: 'x: ',
                                ),
                                onFieldSubmitted: (v) {
                                  final x =
                                      double.tryParse(v) ?? sel.position.x;
                                  _game.updateSelectedPosition(
                                    x,
                                    sel.position.y,
                                  );
                                  setState(() {});
                                  setMState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: sel.position.y.toStringAsFixed(1),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  prefixText: 'y: ',
                                ),
                                onFieldSubmitted: (v) {
                                  final y =
                                      double.tryParse(v) ?? sel.position.y;
                                  _game.updateSelectedPosition(
                                    sel.position.x,
                                    y,
                                  );
                                  setState(() {});
                                  setMState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sel is EditorRect) ...[
                          const Text('Size'),
                          Slider(
                            value: (sel.size.x),
                            min: 16,
                            max: 256,
                            onChanged: (v) {
                              _game.updateSelectedSize(v);
                              setState(() {});
                              setMState(() {});
                            },
                          ),
                        ] else if (sel is EditorCircle) ...[
                          const Text('Radius'),
                          Slider(
                            value: (sel.radius),
                            min: 8,
                            max: 128,
                            onChanged: (v) {
                              _game.updateSelectedSize(v * 2);
                              setState(() {});
                              setMState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text('Color'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final c in [
                              Colors.blueAccent,
                              Colors.orange,
                              Colors.green,
                              Colors.purple,
                              Colors.red,
                              Colors.teal,
                            ])
                              InkWell(
                                onTap: () {
                                  _game.updateSelectedColor(c);
                                  setState(() {});
                                  setMState(() {});
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Opens modal sheet for listing and managing shape instances
  void _openInstancesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instances',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      itemCount: _game.instances.length,
                      itemBuilder: (_, i) {
                        final comp = _game.instances[i];
                        final isSel = identical(comp, _game.selected);
                        final title = comp is EditorRect
                            ? 'Rect'
                            : (comp is EditorCircle
                                  ? 'Circle'
                                  : comp.runtimeType.toString());
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            title == 'Rect'
                                ? Icons.square_rounded
                                : Icons.circle,
                          ),
                          title: Text('$title  (p:${comp.priority})'),
                          selected: isSel,
                          onTap: () {
                            _game.select(comp);
                            setState(() {});
                            Navigator.pop(ctx);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Front',
                                icon: const Icon(Icons.arrow_upward),
                                onPressed: () {
                                  _game.bringToFront(comp);
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Back',
                                icon: const Icon(Icons.arrow_downward),
                                onPressed: () {
                                  _game.sendToBack(comp);
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  comp.removeFromParent();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens modal sheet for managing layer order and grid
  void _openLayersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Layers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.grid_on),
                    title: const Text('Grid'),
                    subtitle: Text(
                      'Visible: ${_game.gridVisible}, cell: ${_game.gridSize.toInt()}',
                    ),
                    trailing: Switch(
                      value: _game.gridVisible,
                      onChanged: (_) {
                        setState(() {
                          _game.toggleGrid();
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Shape order (top to bottom by priority)'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 220,
                    child: ListView(
                      children: [
                        for (final comp
                            in _game.instances..sort(
                              (a, b) => b.priority.compareTo(a.priority),
                            ))
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.drag_indicator),
                            title: Text(
                              comp is EditorRect
                                  ? 'Rect'
                                  : (comp is EditorCircle
                                        ? 'Circle'
                                        : comp.runtimeType.toString()),
                            ),
                            subtitle: Text('priority: ${comp.priority}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _game = EditorGame();
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _game.resumeGame();
      } else {
        _game.pauseGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'Buildcade',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Properties'),
              onTap: () {
                Navigator.pop(context);
                _openPropertiesSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Objects'),
              onTap: () {
                Navigator.pop(context);
                _openObjectsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Instances'),
              onTap: () {
                Navigator.pop(context);
                _openInstancesSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('Layers'),
              onTap: () {
                Navigator.pop(context);
                _openLayersSheet();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Resources'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement resources screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion),
              title: const Text('Scenes'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement scenes screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement settings screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement about dialog or screen
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Buildcade — Flame GUI'),
        actions: [
          IconButton(
            tooltip: 'Add random shape',
            onPressed: _game.addRandom,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Clear scene',
            onPressed: _game.clearScene,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Delete selected',
            onPressed: () => _game.deleteSelected(),
            icon: const Icon(Icons.backspace_outlined),
          ),
          IconButton(
            tooltip: _game.gridVisible ? 'Hide grid' : 'Show grid',
            onPressed: () {
              setState(() => _game.toggleGrid());
            },
            icon: Icon(_game.gridVisible ? Icons.grid_on : Icons.grid_off),
          ),
          IconButton(
            tooltip: _game.snapToGrid
                ? 'Disable snap to grid'
                : 'Enable snap to grid',
            onPressed: () {
              setState(() => _game.toggleSnap());
            },
            icon: Icon(
              _game.snapToGrid ? Icons.my_location : Icons.gps_not_fixed,
            ),
          ),
          PopupMenuButton<double>(
            tooltip: 'Grid size',
            onSelected: (v) => setState(() => _game.setGridSize(v)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 8, child: Text('Grid: 8')),
              PopupMenuItem(value: 16, child: Text('Grid: 16')),
              PopupMenuItem(value: 24, child: Text('Grid: 24')),
              PopupMenuItem(value: 32, child: Text('Grid: 32')),
              PopupMenuItem(value: 48, child: Text('Grid: 48')),
              PopupMenuItem(value: 64, child: Text('Grid: 64')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.grid_3x3),
                  const SizedBox(width: 4),
                  Text('${_game.gridSize.toInt()}'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // The game view
          GameWidget(game: _game),

          // Bottom toolbar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              child: SafeArea(
                // bottom: false,
                top: false,
                child: Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: _openObjectsSheet,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category),
                          // SizedBox(width: 6),
                          // Text('Objects'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _openPropertiesSheet,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune),
                          // SizedBox(width: 6),
                          // Text('Properties'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _openInstancesSheet,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt),
                          // SizedBox(width: 6),
                          // Text('Instances'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _openLayersSheet,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers),
                          // SizedBox(width: 6),
                          // Text('Layers'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _playing ? 'Pause' : 'Play',
                      onPressed: _togglePlay,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
