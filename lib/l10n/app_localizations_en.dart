// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navTrips => 'Trips';

  @override
  String get navProfile => 'Profile';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get gotIt => 'Got it';

  @override
  String get all => 'All';

  @override
  String nOfM(int n, int m) {
    return '$n of $m';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String quantitySuffix(int n) {
    return '(×$n)';
  }

  @override
  String get copyWord => 'copy';

  @override
  String get conditionReady => 'Trail-ready';

  @override
  String get conditionNeedsRepair => 'Needs repair';

  @override
  String get conditionReplace => 'Needs replacing';

  @override
  String get packFood => 'Food';

  @override
  String get packGear => 'Gear';

  @override
  String get packWater => 'Water';

  @override
  String get seedPacks => 'Packs';

  @override
  String get seedSleep => 'Sleep system';

  @override
  String get seedKitchen => 'Kitchen';

  @override
  String get seedClothing => 'Clothing';

  @override
  String get uncategorized => 'Unsorted';

  @override
  String get draft => 'Draft';

  @override
  String get categoryHasChildren =>
      'Delete or move its subcategories first — this category still has some.';

  @override
  String get categoryEmpty => 'Nothing here yet';

  @override
  String get addItem => 'Add item';

  @override
  String takeN(int n) {
    return 'Take $n';
  }

  @override
  String get categoryNameRequired => 'Enter a category name';

  @override
  String get noCategoriesYetInfo =>
      'There are no categories yet — create one first, and you can then make it the parent of new ones.';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get parentCategory => 'Parent category';

  @override
  String get noParent => 'None (top-level category)';

  @override
  String get section => 'Section';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Color';

  @override
  String get itemNameRequired => 'Enter an item name';

  @override
  String get weightRequired => 'Enter a weight';

  @override
  String get editItem => 'Edit item';

  @override
  String get itemName => 'Item name';

  @override
  String get weight => 'Weight';

  @override
  String get unitG => 'g';

  @override
  String get unitOz => 'oz';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String get weightUnits => 'Weight units';

  @override
  String get unitsMetric => 'Kilograms';

  @override
  String get unitsImperial => 'Pounds';

  @override
  String get quantity => 'Quantity';

  @override
  String weightTotal(String weight) {
    return '= $weight total';
  }

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get createCategory => 'New category';

  @override
  String get condition => 'Condition';

  @override
  String get targetWeightTitle => 'Target pack weight';

  @override
  String weightIn(String unit) {
    return 'Weight ($unit)';
  }

  @override
  String get clearTargetHint => '0 or empty removes the target';

  @override
  String get emptyPackTitle => 'Your pack is empty';

  @override
  String get emptyPackSubtitle =>
      'Tick gear in Inventory to add it to your pack and see its weight.';

  @override
  String get goToInventory => 'Go to Inventory';

  @override
  String get setTarget => 'Set target weight';

  @override
  String get changeTarget => 'Change target weight';

  @override
  String get baseWeightHint => 'Gear and pack only — no food or water';

  @override
  String get removeFromTrip => 'Remove from trip';

  @override
  String get totalWeight => 'Total';

  @override
  String get baseWeight => 'Base';

  @override
  String get packingChecklist => 'Packing checklist';

  @override
  String get packDone => 'All packed';

  @override
  String get packingSubtitle => 'Tick off what\'s already in your pack';

  @override
  String get emptyInventory => 'Your inventory is empty';

  @override
  String get addFirstItem => 'Add your first item';

  @override
  String get myInventory => 'My inventory';

  @override
  String get searchHint => 'Find an item…';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get filters => 'Filters';

  @override
  String get resetAll => 'Reset all';

  @override
  String get sort => 'Sort';

  @override
  String get lightestFirst => 'Lightest first';

  @override
  String get heaviestFirst => 'Heaviest first';

  @override
  String get defaultOrder => 'Default';

  @override
  String showItems(String items) {
    return 'Show ($items)';
  }

  @override
  String get packingFor => 'Packing for: ';

  @override
  String get startOver => 'Start over';

  @override
  String get packingHint =>
      'Tick off what\'s already in your pack. The list itself is put together with the checkboxes in Inventory.';

  @override
  String get allPacked => 'All packed — ready to go';

  @override
  String packedProgress(int packed, int total) {
    return '$packed of $total packed';
  }

  @override
  String get profile => 'Profile';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get tripDates => 'Trip dates';

  @override
  String get editTrip => 'Edit trip';

  @override
  String get newTrip => 'New trip';

  @override
  String get name => 'Name';

  @override
  String get tripNameHint => 'e.g. Weekend in the mountains';

  @override
  String get datesOptional => 'Dates (optional)';

  @override
  String get pickDates => 'Pick dates';

  @override
  String get clearDates => 'Clear dates';

  @override
  String targetOptional(String unit) {
    return 'Target pack weight, $unit (optional)';
  }

  @override
  String get startFrom => 'Start from';

  @override
  String get emptyList => 'Empty list';

  @override
  String listOfTrip(String name) {
    return 'List from “$name”';
  }

  @override
  String get createTrip => 'Create trip';

  @override
  String get noTrips => 'No trips yet';

  @override
  String get noTripsSubtitle =>
      'Create a trip to put together its gear list and keep an eye on the weight.';

  @override
  String get myTrips => 'My trips';

  @override
  String archive(int n) {
    return 'Archive · $n';
  }

  @override
  String get turnIntoTrip => 'Turn into a trip';

  @override
  String deleteTripTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteTripBody =>
      'This trip\'s list will be deleted. The items themselves stay in Inventory.';

  @override
  String get active => 'Active';

  @override
  String get allTrips => 'All trips';
}
