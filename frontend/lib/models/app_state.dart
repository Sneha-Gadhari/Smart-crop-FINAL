import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // Wizard state
  String selectedState = '';
  String selectedDistrict = '';
  String soilType = '';
  double nitrogen = 60.0;
  double phosphorus = 40.0;
  double potassium = 80.0;
  double ph = 6.5;
  String season = 'Kharif';
  String irrigation = 'Partial';
  double landAcres = 1.0;
  double budget = 20000.0;
  bool hasBudget = false;
  bool hasLabReport = false;
  String language = 'English';

  // Results
  List<Map<String, dynamic>> cropResults = [];
  Map<String, dynamic>? weatherData;
  int selectedCropIndex = 0;
  int visibleCropCount = 5;
  void setVisibleCropCount(int n) {
    visibleCropCount = n;
    notifyListeners();
  }

  void updateSoilFromImage(Map<String, dynamic> soilData) {
    soilType = soilData['soil_type'] ?? '';
    nitrogen = (soilData['estimated_N'] ?? 60).toDouble();
    phosphorus = (soilData['estimated_P'] ?? 40).toDouble();
    potassium = (soilData['estimated_K'] ?? 80).toDouble();
    ph = (soilData['estimated_pH'] ?? 6.5).toDouble();
    notifyListeners();
  }

  void setResults(List<Map<String, dynamic>> results, Map<String, dynamic>? weather) {
    cropResults = results;
    weatherData = weather;
    selectedCropIndex = 0;
    notifyListeners();
  }

  void selectCrop(int index) {
    selectedCropIndex = index;
    notifyListeners();
  }

  void toggleLanguage() {
    language = language == 'English' ? 'हिंदी' : 'English';
    notifyListeners();
  }

  void reset() {
    selectedState = '';
    selectedDistrict = '';
    visibleCropCount = 5;
    soilType = '';
    nitrogen = 60.0;
    phosphorus = 40.0;
    potassium = 80.0;
    ph = 6.5;
    season = 'Kharif';
    irrigation = 'Partial';
    landAcres = 1.0;
    budget = 20000.0;
    hasBudget = false;
    hasLabReport = false;
    cropResults = [];
    weatherData = null;
    selectedCropIndex = 0;
    notifyListeners();
  }
}
