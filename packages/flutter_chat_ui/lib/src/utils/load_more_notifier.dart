import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] used to track the height and loading state
/// of the "Load More" indicator widget.
class LoadMoreNotifier extends ChangeNotifier {
  double _height = 0;
  bool _isLoading = false;
  double _heightStart = 0;
  bool _isLoadingStart = false;

  /// The current measured height of the LoadMore widget.
  double get height => _height;

  /// Whether the LoadMore widget is currently indicating a loading state.
  bool get isLoading => _isLoading;

  /// The current measured height of the LoadMore start widget.
  double get heightStart => _heightStart;

  /// Whether the LoadMore start widget is currently indicating a loading state.
  bool get isLoadingStart => _isLoadingStart;

  /// Sets the height of the LoadMore widget and notifies listeners if it changes.
  void setHeight(double newHeight) {
    if (_height != newHeight) {
      _height = newHeight;
      notifyListeners();
    }
  }

  /// Sets the loading state and notifies listeners if it changes.
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Sets the height of the LoadMore start widget and notifies listeners if it changes.
  void setHeightStart(double newHeight) {
    if (_heightStart != newHeight) {
      _heightStart = newHeight;
      notifyListeners();
    }
  }

  /// Sets the loading start state and notifies listeners if it changes.
  void setLoadingStart(bool loading) {
    if (_isLoadingStart != loading) {
      _isLoadingStart = loading;
      notifyListeners();
    }
  }
}
