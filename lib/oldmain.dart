import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- DATA MODELS ---

/// Helper for generating unique IDs (simple timestamp-based for this example).
/// In a real application, consider a UUID package.
String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Represents a single media item (e.g., a specific DVD, book, or game).
class MediaItem {
  final String id;
  String title;
  String? notes;
  String mediaTypeId; // ID of the MediaType it belongs to
  String? author;
  int? releaseYear;

  MediaItem({
    required this.id,
    required this.title,
    this.notes,
    required this.mediaTypeId,
    this.author,
    this.releaseYear,
  });

  /// Creates a copy of this [MediaItem] with optionally updated values.
  MediaItem copyWith({
    String? id,
    String? title,
    String? notes,
    String? mediaTypeId,
    String? author,
    int? releaseYear,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      mediaTypeId: mediaTypeId ?? this.mediaTypeId,
      author: author ?? this.author,
      releaseYear: releaseYear ?? this.releaseYear,
    );
  }

  /// Converts a [MediaItem] instance to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'notes': notes,
      'mediaTypeId': mediaTypeId,
      'author': author,
      'releaseYear': releaseYear,
    };
  }

  /// Creates a [MediaItem] instance from a JSON-compatible map.
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id']! as String,
      title: json['title']! as String,
      notes: json['notes'] as String?,
      mediaTypeId: json['mediaTypeId']! as String,
      author: json['author'] as String?,
      releaseYear: json['releaseYear'] as int?,
    );
  }
}

/// Represents a category or "shelf" for media items (e.g., "DVDs", "Books").
class MediaType {
  final String id;
  String name;
  IconData icon;

  MediaType({required this.id, required this.name, required this.icon});

  /// Creates a copy of this [MediaType] with optionally updated values.
  MediaType copyWith({
    String? id,
    String? name,
    IconData? icon,
  }) {
    return MediaType(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
    );
  }

  /// Converts a [MediaType] instance to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
    };
  }

  /// Creates a [MediaType] instance from a JSON-compatible map.
  factory MediaType.fromJson(Map<String, dynamic> json) {
    return MediaType(
      id: json['id']! as String,
      name: json['name']! as String,
      icon: IconData(
        json['iconCodePoint']! as int,
        fontFamily: json['iconFontFamily']! as String,
      ),
    );
  }
}

/// Manages the collection of media types and media items using the Provider pattern.
class MediaCollectionData extends ChangeNotifier {
  static const String _storageKey = 'mediaCollectionData';

  final List<MediaType> _mediaTypes;
  final List<MediaItem> _mediaItems;

  // Private constructor for internal use (initializing with data)
  MediaCollectionData._({required List<MediaType> mediaTypes, required List<MediaItem> mediaItems})
      : _mediaTypes = mediaTypes,
        _mediaItems = mediaItems;

  /// Factory constructor to create a new instance, loading data from shared preferences.
  /// If no data is found, it initializes with empty lists.
  static Future<MediaCollectionData> create() async {
    return _loadFromPreferences();
  }

  /// Loads media data from [SharedPreferences].
  static Future<MediaCollectionData> _loadFromPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString != null) {
      try {
        final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;
        final List<MediaType> loadedMediaTypes = (data['mediaTypes'] as List<dynamic>)
            .map<MediaType>((dynamic item) => MediaType.fromJson(item as Map<String, dynamic>))
            .toList();
        final List<MediaItem> loadedMediaItems = (data['mediaItems'] as List<dynamic>)
            .map<MediaItem>((dynamic item) => MediaItem.fromJson(item as Map<String, dynamic>))
            .toList();
        return MediaCollectionData._(mediaTypes: loadedMediaTypes, mediaItems: loadedMediaItems);
      } catch (e) {
        // Log error or handle corrupted data by returning empty
        // print('Error loading data from SharedPreferences: $e');
      }
    }
    // Return empty data if nothing found or error occurred
    return MediaCollectionData._(mediaTypes: <MediaType>[], mediaItems: <MediaItem>[]);
  }

  /// Saves the current media data to [SharedPreferences].
  Future<void> _saveToPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> dataToSave = <String, dynamic>{
      'mediaTypes': _mediaTypes.map<Map<String, dynamic>>((MediaType type) => type.toJson()).toList(),
      'mediaItems': _mediaItems.map<Map<String, dynamic>>((MediaItem item) => item.toJson()).toList(),
    };
    final String jsonString = json.encode(dataToSave);
    await prefs.setString(_storageKey, jsonString);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    unawaited(_saveToPreferences()); // Save data whenever state changes
  }

  /// Returns an unmodifiable list of all media types.
  List<MediaType> get mediaTypes => List<MediaType>.unmodifiable(_mediaTypes);

  /// Returns an unmodifiable list of all media items.
  List<MediaItem> get mediaItems => List<MediaItem>.unmodifiable(_mediaItems);

  /// Retrieves media items belonging to a specific media type.
  List<MediaItem> getMediaItemsForType(String mediaTypeId) {
    return _mediaItems.where((MediaItem item) => item.mediaTypeId == mediaTypeId).toList();
  }

  /// Retrieves a media type by its ID.
  MediaType? getMediaTypeById(String id) {
    try {
      return _mediaTypes.firstWhere((MediaType type) => type.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Adds a new media type to the collection.
  void addMediaType(MediaType type) {
    _mediaTypes.add(type);
    notifyListeners();
  }

  /// Updates an existing media type.
  void updateMediaType(MediaType updatedType) {
    final int index = _mediaTypes.indexWhere((MediaType type) => type.id == updatedType.id);
    if (index != -1) {
      _mediaTypes[index] = updatedType;
      notifyListeners();
    }
  }

  /// Deletes a media type and all associated media items.
  void deleteMediaType(String id) {
    _mediaTypes.removeWhere((MediaType type) => type.id == id);
    _mediaItems.removeWhere((MediaItem item) => item.mediaTypeId == id);
    notifyListeners();
  }

  /// Reorders media types in the collection.
  void reorderMediaTypes(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _mediaTypes.length ||
        newIndex < 0 || newIndex > _mediaTypes.length) {
      return; // Invalid indices
    }

    if (oldIndex < newIndex) {
      newIndex -= 1; // Adjust newIndex if moving item downwards
    }

    final MediaType item = _mediaTypes.removeAt(oldIndex);
    _mediaTypes.insert(newIndex, item);
    notifyListeners();
  }

  /// Adds a new media item to the collection.
  void addMediaItem(MediaItem item) {
    _mediaItems.add(item);
    notifyListeners();
  }

  /// Adds multiple new media items to the collection.
  void addMediaItems(List<MediaItem> items) {
    _mediaItems.addAll(items);
    notifyListeners();
  }

  /// Updates an existing media item.
  void updateMediaItem(MediaItem updatedItem) {
    final int index = _mediaItems.indexWhere((MediaItem item) => item.id == updatedItem.id);
    if (index != -1) {
      _mediaItems[index] = updatedItem;
      notifyListeners();
    }
  }

  /// Deletes a media item.
  void deleteMediaItem(String id) {
    _mediaItems.removeWhere((MediaItem item) => item.id == id);
    notifyListeners();
  }
}

/// Defines available sorting orders for media items.
enum MediaItemSortOrder {
  addedOrder,
  titleAsc,
  authorAsc,
  releaseYearAsc,
}

/// Extension to provide display names for [MediaItemSortOrder] enum values.
extension MediaItemSortOrderExtension on MediaItemSortOrder {
  String get displayName {
    switch (this) {
      case MediaItemSortOrder.addedOrder:
        return 'Added Order';
      case MediaItemSortOrder.titleAsc:
        return 'Title (A-Z)';
      case MediaItemSortOrder.authorAsc:
        return 'Author (A-Z)';
      case MediaItemSortOrder.releaseYearAsc:
        return 'Release Year (Asc)';
    }
  }
}

// --- MAIN APP WIDGET ---

/// The root widget for the Media Collection Manager application content.
/// Wrapped by `_AppInitializationWrapper` for loading logic.
class MediaCollectionAppContent extends StatelessWidget {
  const MediaCollectionAppContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fallback to a seeded color scheme as DynamicColorBuilder is not available
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Media Mage',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
      ),
      themeMode: ThemeMode.system, // Use system theme settings (light/dark)
      home: const _MediaCollectionHomePage(),
    );
  }
}

/// A wrapper widget that handles asynchronous data loading.
class _AppInitializationWrapper extends StatefulWidget {
  const _AppInitializationWrapper({Key? key}) : super(key: key);

  @override
  State<_AppInitializationWrapper> createState() => _AppInitializationWrapperState();
}

class _AppInitializationWrapperState extends State<_AppInitializationWrapper> {
  Future<MediaCollectionData>? _dataInitializationFuture;

  @override
  void initState() {
    super.initState();
    _dataInitializationFuture = _initializeData();
  }

  /// Initializes data by loading it from persistence.
  Future<MediaCollectionData> _initializeData() async {
    // Load existing data; no demo data is created on first launch.
    final MediaCollectionData data = await MediaCollectionData.create();
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaCollectionData>(
      future: _dataInitializationFuture,
      builder: (BuildContext context, AsyncSnapshot<MediaCollectionData> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Error initializing data: ${snapshot.error}', textAlign: TextAlign.center),
                ),
              ),
            );
          } else if (snapshot.hasData) {
            final MediaCollectionData loadedData = snapshot.data!;
            return ChangeNotifierProvider<MediaCollectionData>.value(
              value: loadedData,
              builder: (BuildContext context, Widget? child) {
                return const MediaCollectionAppContent();
              },
            );
          }
        }
        // Show a loading indicator while data is being loaded
        return const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}

// --- HOME PAGE WIDGET ---

/// The main page of the application, displaying selected media items.
class _MediaCollectionHomePage extends StatefulWidget {
  const _MediaCollectionHomePage({Key? key}) : super(key: key);

  @override
  State<_MediaCollectionHomePage> createState() => _MediaCollectionHomePageState();
}

class _MediaCollectionHomePageState extends State<_MediaCollectionHomePage> {
  String? _selectedMediaTypeId; // ID of the currently active shelf
  bool _isSearching = false; // State for controlling search bar visibility
  late TextEditingController _searchController; // Controller for the search input
  String _searchQuery = ''; // Current search query
  late MediaItemSortOrder _selectedSortOrder; // Current sorting order

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _selectedSortOrder = MediaItemSortOrder.addedOrder; // Default sort order

    // Set initial selected media type after the first frame to ensure context and data are ready.
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final MediaCollectionData data = Provider.of<MediaCollectionData>(context, listen: false);
      if (data.mediaTypes.isNotEmpty) {
        setState(() {
          _selectedMediaTypeId = data.mediaTypes.first.id;
        });
      }
    });
  }

  // Callback for when the search text changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Builds the application's AppBar, dynamically switching between title and search field.
  AppBar _buildAppBar(BuildContext context, MediaType? selectedType, MediaCollectionData mediaData) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear(); // Clear search query when exiting search mode
              _searchQuery = ''; // Ensure state reflects cleared controller
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search ${selectedType?.name ?? 'items'}...',
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                // _searchQuery will be updated via listener
              },
            )
                : null,
          ),
          onChanged: (String value) {
            // The _onSearchChanged listener handles setState for _searchQuery
          },
        ),
      );
    } else {
      return AppBar(
        title: Text(selectedType?.name ?? 'Media Mage'), // Use 'Media Mage' for empty state
        actions: mediaData.mediaTypes.isNotEmpty
            ? <Widget>[
          // Filter button
          PopupMenuButton<MediaItemSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Items',
            initialValue: _selectedSortOrder,
            onSelected: (MediaItemSortOrder newOrder) {
              setState(() {
                _selectedSortOrder = newOrder;
              });
            },
            itemBuilder: (BuildContext context) {
              return MediaItemSortOrder.values.map<PopupMenuItem<MediaItemSortOrder>>((MediaItemSortOrder order) {
                return PopupMenuItem<MediaItemSortOrder>(
                  value: order,
                  child: Text(order.displayName),
                );
              }).toList();
            },
          ),
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
                _searchController.clear(); // Clear previous search when entering search mode
                _searchQuery = ''; // Ensure state reflects cleared controller
              });
            },
          ),
        ]
            : null, // No actions if no media types
      );
    }
  }

  /// Applies the selected sorting order to a list of media items.
  List<MediaItem> _applySorting(List<MediaItem> items) {
    // Create a modifiable copy to sort
    final List<MediaItem> sortedItems = List<MediaItem>.from(items);

    switch (_selectedSortOrder) {
      case MediaItemSortOrder.addedOrder:
      // Items are typically in 'added order' by virtue of how they are stored
      // or by their timestamp-based ID. Explicitly sort by ID for consistency.
        sortedItems.sort((MediaItem a, MediaItem b) => a.id.compareTo(b.id));
        break;
      case MediaItemSortOrder.titleAsc:
        sortedItems.sort((MediaItem a, MediaItem b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MediaItemSortOrder.authorAsc:
        sortedItems.sort((MediaItem a, MediaItem b) {
          final String authorA = a.author?.toLowerCase() ?? '';
          final String authorB = b.author?.toLowerCase() ?? '';
          return authorA.compareTo(authorB);
        });
        break;
      case MediaItemSortOrder.releaseYearAsc:
        sortedItems.sort((MediaItem a, MediaItem b) {
          // Treat null release years as very high so they come last in ascending sort
          final int yearA = a.releaseYear ?? 9999;
          final int yearB = b.releaseYear ?? 9999;
          return yearA.compareTo(yearB);
        });
        break;
    }
    return sortedItems;
  }

  @override
  Widget build(BuildContext context) {
    final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context);
    MediaType? selectedType;

    // Ensure _selectedMediaTypeId always points to a valid type if types exist
    if (_selectedMediaTypeId != null && mediaData.getMediaTypeById(_selectedMediaTypeId!) == null) {
      // If the previously selected type was deleted, reset selection
      _selectedMediaTypeId = null;
    }

    // If a type is explicitly selected, use it. Otherwise, default to the first available.
    if (_selectedMediaTypeId != null) {
      selectedType = mediaData.getMediaTypeById(_selectedMediaTypeId!);
    }
    // If no specific type is selected, or the selected one was invalid, pick the first if available.
    selectedType ??= mediaData.mediaTypes.firstWhereOrNull((MediaType _) => true);

    // Update _selectedMediaTypeId if it was reset or newly assigned
    if (selectedType != null && _selectedMediaTypeId != selectedType.id) {
      _selectedMediaTypeId = selectedType.id;
    }

    // If no media types exist at all (initial state or all deleted)
    if (mediaData.mediaTypes.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(context, null, mediaData), // Pass null for selectedType
        drawer: _buildDrawer(context, mediaData),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.collections_bookmark_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  'No media shelves created yet!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Go to "Manage Shelves" in the drawer to add your first media type.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showManageMediaTypesDialog(context),
          label: const Text('Add Shelf'),
          icon: const Icon(Icons.add),
        ),
      );
    }

    // Now, we are sure selectedType is not null here, because if it was,
    // the previous `if (mediaData.mediaTypes.isEmpty)` block would have returned.
    // Explicitly cast to a non-nullable type to satisfy the analyzer.
    final MediaType finalSelectedType = selectedType!;

    final List<MediaItem> currentShelfItems = mediaData.getMediaItemsForType(finalSelectedType.id);
    List<MediaItem> displayItems;

    // Apply search filter if a query is present
    if (_searchQuery.isNotEmpty) {
      final String lowerCaseQuery = _searchQuery.toLowerCase();
      displayItems = currentShelfItems.where((MediaItem item) {
        final String lowerCaseTitle = item.title.toLowerCase();
        final String lowerCaseAuthor = item.author?.toLowerCase() ?? '';
        final String lowerCaseNotes = item.notes?.toLowerCase() ?? '';
        final String lowerCaseReleaseYear = item.releaseYear?.toString().toLowerCase() ?? '';
        return lowerCaseTitle.contains(lowerCaseQuery) ||
            lowerCaseAuthor.contains(lowerCaseQuery) ||
            lowerCaseNotes.contains(lowerCaseQuery) ||
            lowerCaseReleaseYear.contains(lowerCaseQuery);
      }).toList();
    } else {
      displayItems = currentShelfItems;
    }

    // Apply sorting *after* search filtering
    displayItems = _applySorting(displayItems);

    return Scaffold(
      appBar: _buildAppBar(context, finalSelectedType, mediaData),
      drawer: _buildDrawer(context, mediaData),
      body: displayItems.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(finalSelectedType.icon, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No results found for "$_searchQuery" in "${finalSelectedType.name}"'
                    : 'No ${finalSelectedType.name} on this shelf yet!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_searchQuery.isEmpty) // Only show add instruction if not searching
                Text(
                  'Tap the "+" button to add your first ${finalSelectedType.name.toLowerCase().replaceAll('s', '')}.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: displayItems.length,
        itemBuilder: (BuildContext context, int index) {
          final MediaItem item = displayItems[index];
          return _MediaItemListItem(
            item: item,
            onEdit: () => _showAddEditMediaItemDialog(context, item: item, mediaTypeId: finalSelectedType.id),
            onDelete: () {
              showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Delete Item?'),
                    content: Text('Are you sure you want to delete "${item.title}"?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          mediaData.deleteMediaItem(item.id);
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: !_isSearching // Hide FAB when searching. selectedType is guaranteed non-null here.
          ? FloatingActionButton(
        onPressed: () => _showAddEditMediaItemDialog(context, mediaTypeId: finalSelectedType.id),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  /// Builds the application's drawer for navigation and management options.
  Widget _buildDrawer(BuildContext context, MediaCollectionData mediaData) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Your Shelves',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          ...mediaData.mediaTypes.map<Widget>((MediaType type) {
            return ListTile(
              leading: Icon(type.icon),
              title: Text(type.name),
              selected: _selectedMediaTypeId == type.id,
              onTap: () {
                setState(() {
                  _selectedMediaTypeId = type.id;
                  _isSearching = false; // Exit search mode when changing shelves
                  _searchController.clear();
                  _searchQuery = '';
                });
                Navigator.of(context).pop(); // Close the drawer
              },
            );
          }).toList(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Manage Shelves'),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer
              _showManageMediaTypesDialog(context);
            },
          ),
        ],
      ),
    );
  }

  /// Displays a modal bottom sheet for adding or editing a media item.
  void _showAddEditMediaItemDialog(BuildContext context, {MediaItem? item, required String mediaTypeId}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // Allows the sheet to take full height
      builder: (BuildContext dialogContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
          child: _AddEditMediaItemScreen(
            mediaItem: item,
            initialMediaTypeId: mediaTypeId,
          ),
        );
      },
    );
  }

  /// Displays a modal bottom sheet for managing media types (shelves).
  void _showManageMediaTypesDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
          child: const _ManageMediaTypesScreen(),
        );
      },
    );
  }
}

/// An extension to easily find the first element or return null.
extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

// --- MEDIA ITEM LIST ITEM WIDGET ---

/// A list tile widget to display a single media item with options to edit and delete.
class _MediaItemListItem extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MediaItemListItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final MediaType? mediaType = Provider.of<MediaCollectionData>(context).getMediaTypeById(item.mediaTypeId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            mediaType?.icon ?? Icons.category_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.author != null && item.author!.isNotEmpty)
              Text(
                item.author!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.releaseYear != null)
              Text(
                'Released: ${item.releaseYear}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.notes != null && item.notes!.isNotEmpty)
              Text(
                item.notes!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit Item',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete Item',
            ),
          ],
        ),
      ),
    );
  }
}

// --- ADD/EDIT MEDIA ITEM SCREEN ---

/// A screen for adding a new media item or editing an existing one.
class _AddEditMediaItemScreen extends StatefulWidget {
  final MediaItem? mediaItem; // If null, we are adding a new item
  final String initialMediaTypeId;

  const _AddEditMediaItemScreen({
    this.mediaItem,
    required this.initialMediaTypeId,
    Key? key,
  }) : super(key: key);

  @override
  State<_AddEditMediaItemScreen> createState() => _AddEditMediaItemScreenState();
}

class _AddEditMediaItemScreenState extends State<_AddEditMediaItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _authorController;
  late TextEditingController _releaseYearController;
  late String _selectedMediaTypeId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.mediaItem?.title ?? '');
    _notesController = TextEditingController(text: widget.mediaItem?.notes ?? '');
    _authorController = TextEditingController(text: widget.mediaItem?.author ?? '');
    _releaseYearController = TextEditingController(text: widget.mediaItem?.releaseYear?.toString() ?? '');

    final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);
    String initialSelectedId = widget.mediaItem?.mediaTypeId ?? widget.initialMediaTypeId;

    // Ensure the initialSelectedId is valid among existing media types.
    // If not, default to the first available media type, or empty string if none exist.
    if (mediaData.getMediaTypeById(initialSelectedId) == null) {
      if (mediaData.mediaTypes.isNotEmpty) {
        _selectedMediaTypeId = mediaData.mediaTypes.first.id;
      } else {
        // This case should ideally not be reachable as FAB for add/edit would be null
        // if no shelves exist, but for robustness:
        _selectedMediaTypeId = '';
      }
    } else {
      _selectedMediaTypeId = initialSelectedId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _authorController.dispose();
    _releaseYearController.dispose();
    super.dispose();
  }

  /// Saves or updates the media item in the collection.
  void _saveMediaItem() {
    if (_formKey.currentState!.validate()) {
      final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);

      final int? parsedReleaseYear = int.tryParse(_releaseYearController.text.trim());

      final MediaItem newItem = MediaItem(
        id: widget.mediaItem?.id ?? _generateId(),
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        mediaTypeId: _selectedMediaTypeId,
        author: _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : null,
        releaseYear: parsedReleaseYear,
      );

      if (widget.mediaItem == null) {
        mediaData.addMediaItem(newItem);
      } else {
        mediaData.updateMediaItem(newItem);
      }
      Navigator.of(context).pop(); // Close the bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context);
    final String titleText = widget.mediaItem == null ? 'Add New Item' : 'Edit Item';

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text(titleText, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _releaseYearController,
                    decoration: const InputDecoration(
                      labelText: 'Release Year (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly, // Allow only digits
                      LengthLimitingTextInputFormatter(4), // Limit to 4 digits for year
                    ],
                    validator: (String? value) {
                      if (value != null && value.isNotEmpty) {
                        final int? year = int.tryParse(value);
                        if (year == null || year < 1000 || year > DateTime.now().year + 5) {
                          return 'Please enter a valid year (e.g., 2023)';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedMediaTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Shelf Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: mediaData.mediaTypes.map<DropdownMenuItem<String>>((MediaType type) {
                      return DropdownMenuItem<String>(
                        value: type.id,
                        child: Row(
                          children: <Widget>[
                            Icon(type.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(type.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedMediaTypeId = newValue;
                        });
                      }
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a shelf type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveMediaItem,
                      icon: Icon(widget.mediaItem == null ? Icons.add : Icons.save),
                      label: Text(widget.mediaItem == null ? 'Add Item' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ], // Closes children of inner Column
              ), // Closes inner Column
            ), // Closes Form
          ], // Closes children of outer Column
        ), // Closes outer Column
      ), // Closes Container
    ); // Closes SingleChildScrollView
  }
}

// --- MANAGE MEDIA TYPES SCREEN ---

/// A screen for adding, editing, and deleting media types (shelves).
class _ManageMediaTypesScreen extends StatefulWidget {
  const _ManageMediaTypesScreen({Key? key}) : super(key: key);

  @override
  State<_ManageMediaTypesScreen> createState() => _ManageMediaTypesScreenState();
}

class _ManageMediaTypesScreenState extends State<_ManageMediaTypesScreen> {
  final GlobalKey<FormState> _addTypeFormKey = GlobalKey<FormState>();
  late TextEditingController _newTypeNameController;
  IconData _selectedIcon = Icons.folder_open; // Default icon for new shelves

  // A selected list of common icons for media types
  static const List<IconData> _availableIcons = <IconData>[
    Icons.movie_outlined,
    Icons.book_outlined,
    Icons.videogame_asset_outlined,
    Icons.album_outlined,
    Icons.tv_outlined,
    Icons.newspaper_outlined,
    Icons.collections_bookmark_outlined,
    Icons.photo_library_outlined,
    Icons.folder_open,
    Icons.architecture_outlined,
    Icons.devices_other_outlined,
    Icons.audiotrack_outlined,
    Icons.palette_outlined,
    Icons.fitness_center_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _newTypeNameController = TextEditingController();
  }

  @override
  void dispose() {
    _newTypeNameController.dispose();
    super.dispose();
  }

  /// Adds a new media type to the collection.
  void _addMediaType() {
    if (_addTypeFormKey.currentState!.validate()) {
      final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);
      final String newTypeName = _newTypeNameController.text.trim();

      // Check for duplicate names
      if (mediaData.mediaTypes.any((MediaType type) => type.name.toLowerCase() == newTypeName.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A shelf with this name already exists!')),
        );
        return;
      }

      mediaData.addMediaType(MediaType(id: _generateId(), name: newTypeName, icon: _selectedIcon));
      _newTypeNameController.clear();
      setState(() {
        _selectedIcon = Icons.folder_open; // Reset icon after adding
      });
    }
  }

  /// Displays a dialog to edit an existing media type.
  void _editMediaType(MediaType type) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController editTypeNameController = TextEditingController(text: type.name);
        IconData editSelectedIcon = type.icon;
        final GlobalKey<FormState> editFormKey = GlobalKey<FormState>();

        return AlertDialog(
          title: const Text('Edit Shelf Type'),
          content: StatefulBuilder(
            builder: (BuildContext innerDialogContext, void Function(void Function()) setInnerState) {
              return Form(
                key: editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: editTypeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shelf Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Shelf name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<IconData>(
                      value: editSelectedIcon,
                      decoration: const InputDecoration(
                        labelText: 'Icon',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableIcons.map<DropdownMenuItem<IconData>>((IconData icon) {
                        return DropdownMenuItem<IconData>(
                          value: icon,
                          child: Icon(icon),
                        );
                      }).toList(),
                      onChanged: (IconData? newIcon) {
                        if (newIcon != null) {
                          setInnerState(() {
                            editSelectedIcon = newIcon;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                editTypeNameController.dispose();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (editFormKey.currentState!.validate()) {
                  final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);
                  final String updatedTypeName = editTypeNameController.text.trim();

                  // Check for duplicate names, excluding the current type being edited
                  if (mediaData.mediaTypes.any((MediaType existingType) =>
                  existingType.id != type.id && existingType.name.toLowerCase() == updatedTypeName.toLowerCase())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('A shelf with this name already exists!')),
                    );
                    return;
                  }

                  mediaData.updateMediaType(type.copyWith(name: updatedTypeName, icon: editSelectedIcon));
                  editTypeNameController.dispose();
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Displays a confirmation dialog before deleting a media type.
  void _confirmDeleteMediaType(BuildContext context, MediaType type) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Shelf?'),
          content: Text('Are you sure you want to delete the "${type.name}" shelf and all its items? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Provider.of<MediaCollectionData>(context, listen: false).deleteMediaType(type.id);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Exports all media items of a given type to a JSON string.
  Future<void> _exportShelfItems(BuildContext context, MediaType type) async {
    final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);
    final List<MediaItem> itemsToExport = mediaData.getMediaItemsForType(type.id);

    if (itemsToExport.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The "${type.name}" shelf is empty, nothing to export.')),
      );
      return;
    }

    final List<Map<String, dynamic>> jsonList = itemsToExport.map<Map<String, dynamic>>((MediaItem item) => item.toJson()).toList();
    final String prettyJson = const JsonEncoder.withIndent('  ').convert(jsonList);

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Export "${type.name}" Items'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Copy the JSON data below:'),
                const SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.4),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(dialogContext).dividerColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: SelectableText(
                    prettyJson,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('JSON copied to clipboard!')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
          ],
        );
      },
    );
  }

  /// Imports media items from a JSON string into a given media type.
  Future<void> _importShelfItems(BuildContext context, MediaType type) async {
    final TextEditingController importController = TextEditingController();

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Import Items into "${type.name}"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Paste JSON data for items below. Items will be added to this shelf. Existing IDs will be ignored and new unique IDs will be assigned.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: importController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'JSON Data',
                    hintText: '[{"title": "Book Title", "author": "Author Name", "releaseYear": 2023, "notes": "Some notes"}]',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                importController.dispose();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String jsonInput = importController.text.trim();
                importController.dispose();

                if (jsonInput.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('No JSON data provided.')),
                  );
                  return;
                }

                try {
                  final dynamic decoded = json.decode(jsonInput);
                  if (decoded is! List<dynamic>) {
                    throw const FormatException('Expected a JSON array of items.');
                  }

                  final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context, listen: false);
                  int importedCount = 0;
                  final List<MediaItem> newItems = <MediaItem>[];

                  for (final dynamic itemJson in decoded) {
                    if (itemJson is! Map<String, dynamic>) {
                      continue; // Skip malformed individual items
                    }
                    try {
                      final MediaItem tempItem = MediaItem.fromJson(itemJson);
                      newItems.add(tempItem.copyWith(
                        id: _generateId(), // Assign a new unique ID
                        mediaTypeId: type.id, // Ensure it's assigned to the target shelf
                      ));
                      importedCount++;
                    } catch (e) {
                      // print('Skipping malformed item: $e, JSON: $itemJson');
                    }
                  }

                  if (newItems.isNotEmpty) {
                    mediaData.addMediaItems(newItems);
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(); // Close import dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully imported $importedCount items into "${type.name}".')),
                  );
                } on FormatException catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('JSON format error: ${e.message}')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('An unexpected error occurred during import: $e')),
                  );
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaCollectionData mediaData = Provider.of<MediaCollectionData>(context);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Text('Manage Media Shelves', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Form(
              key: _addTypeFormKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _newTypeNameController,
                    decoration: const InputDecoration(
                      labelText: 'New Shelf Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.collections_bookmark_outlined),
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Shelf name cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    value: _selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Shelf Icon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _availableIcons.map<DropdownMenuItem<IconData>>((IconData icon) {
                      return DropdownMenuItem<IconData>(
                        value: icon,
                        child: Icon(icon),
                      );
                    }).toList(),
                    onChanged: (IconData? newIcon) {
                      if (newIcon != null) {
                        setState(() {
                          _selectedIcon = newIcon;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addMediaType,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Shelf'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Existing Shelves', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            mediaData.mediaTypes.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('No shelves created yet.'),
            )
                : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mediaData.mediaTypes.length,
              onReorder: (int oldIndex, int newIndex) {
                Provider.of<MediaCollectionData>(context, listen: false).reorderMediaTypes(oldIndex, newIndex);
              },
              itemBuilder: (BuildContext listContext, int index) {
                final MediaType type = mediaData.mediaTypes[index];
                return Card(
                  key: ValueKey<String>(type.id), // Unique key required for ReorderableListView
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    // The `ReorderableDragHandle` widget was introduced in Flutter 3.3.0.
                    // If you are using an older Flutter version, it will cause a compile error.
                    // By default, `ReorderableListView` makes the entire list item draggable.
                    // Removing `ReorderableDragHandle` relies on this default behavior.
                    // If you intend for only a specific part (like the icon) to be the drag handle
                    // and are on a Flutter version 3.3.0 or higher, you would typically
                    // set `buildDefaultDragHandles: false` on `ReorderableListView.builder`
                    // and then use `ReorderableDragHandle` as a child in your `itemBuilder`.
                    leading: Icon(type.icon),
                    title: Text(type.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editMediaType(type),
                          tooltip: 'Edit Shelf',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDeleteMediaType(context, type),
                          tooltip: 'Delete Shelf',
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More Actions',
                          onSelected: (String choice) {
                            if (choice == 'export') {
                              _exportShelfItems(context, type);
                            } else if (choice == 'import') {
                              _importShelfItems(context, type);
                            }
                          },
                          itemBuilder: (BuildContext popupContext) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'export',
                              child: Text('Export Items'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'import',
                              child: Text('Import Items'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The entry point of the Flutter application.
void main() {
  // Ensure Flutter widgets binding is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const _AppInitializationWrapper());
}