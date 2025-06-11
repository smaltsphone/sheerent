import 'package:flutter/foundation.dart';

class AuthProvider with ChangeNotifier {
  int? userId;
  String? userName;
  bool? isAdmin;
  int? point;

  bool get isLoggedIn => userId != null;

  void login({required int id, required String name, required bool admin, required int point}) {
    userId = id;
    userName = name;
    isAdmin = admin;
    this.point = point;
    notifyListeners();
  }

  void logout() {
    userId = null;
    userName = null;
    isAdmin = null;
    point = null;
    notifyListeners();
  }

  void updatePoint(int newPoint) {
    point = newPoint;
    notifyListeners();
  }

  void updateAdmin(bool admin) {
    isAdmin = admin;
    notifyListeners();
  }
}
