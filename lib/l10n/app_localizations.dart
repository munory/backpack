import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @nOfM.
  ///
  /// In en, this message translates to:
  /// **'{n} of {m}'**
  String nOfM(int n, int m);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String categoryCount(int count);

  /// No description provided for @quantitySuffix.
  ///
  /// In en, this message translates to:
  /// **'(×{n})'**
  String quantitySuffix(int n);

  /// No description provided for @copyWord.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get copyWord;

  /// No description provided for @conditionReady.
  ///
  /// In en, this message translates to:
  /// **'Trail-ready'**
  String get conditionReady;

  /// No description provided for @conditionNeedsRepair.
  ///
  /// In en, this message translates to:
  /// **'Needs repair'**
  String get conditionNeedsRepair;

  /// No description provided for @conditionReplace.
  ///
  /// In en, this message translates to:
  /// **'Needs replacing'**
  String get conditionReplace;

  /// No description provided for @packFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get packFood;

  /// No description provided for @packGear.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get packGear;

  /// No description provided for @packWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get packWater;

  /// No description provided for @seedPacks.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get seedPacks;

  /// No description provided for @seedSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep system'**
  String get seedSleep;

  /// No description provided for @seedKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get seedKitchen;

  /// No description provided for @seedClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get seedClothing;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Unsorted'**
  String get uncategorized;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @categoryHasChildren.
  ///
  /// In en, this message translates to:
  /// **'Delete or move its subcategories first — this category still has some.'**
  String get categoryHasChildren;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get categoryEmpty;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @takeN.
  ///
  /// In en, this message translates to:
  /// **'Take {n}'**
  String takeN(int n);

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a category name'**
  String get categoryNameRequired;

  /// No description provided for @noCategoriesYetInfo.
  ///
  /// In en, this message translates to:
  /// **'There are no categories yet — create one first, and you can then make it the parent of new ones.'**
  String get noCategoriesYetInfo;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get parentCategory;

  /// No description provided for @noParent.
  ///
  /// In en, this message translates to:
  /// **'None (top-level category)'**
  String get noParent;

  /// No description provided for @section.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get section;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @itemNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an item name'**
  String get itemNameRequired;

  /// No description provided for @weightRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight'**
  String get weightRequired;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitOz.
  ///
  /// In en, this message translates to:
  /// **'oz'**
  String get unitOz;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitLb.
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get unitLb;

  /// No description provided for @weightUnits.
  ///
  /// In en, this message translates to:
  /// **'Weight units'**
  String get weightUnits;

  /// No description provided for @unitsMetric.
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get unitsMetric;

  /// No description provided for @unitsImperial.
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get unitsImperial;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @weightTotal.
  ///
  /// In en, this message translates to:
  /// **'= {weight} total'**
  String weightTotal(String weight);

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get createCategory;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @targetWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Target pack weight'**
  String get targetWeightTitle;

  /// No description provided for @weightIn.
  ///
  /// In en, this message translates to:
  /// **'Weight ({unit})'**
  String weightIn(String unit);

  /// No description provided for @clearTargetHint.
  ///
  /// In en, this message translates to:
  /// **'0 or empty removes the target'**
  String get clearTargetHint;

  /// No description provided for @emptyPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Your pack is empty'**
  String get emptyPackTitle;

  /// No description provided for @emptyPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tick gear in Inventory to add it to your pack and see its weight.'**
  String get emptyPackSubtitle;

  /// No description provided for @goToInventory.
  ///
  /// In en, this message translates to:
  /// **'Go to Inventory'**
  String get goToInventory;

  /// No description provided for @setTarget.
  ///
  /// In en, this message translates to:
  /// **'Set target weight'**
  String get setTarget;

  /// No description provided for @changeTarget.
  ///
  /// In en, this message translates to:
  /// **'Change target weight'**
  String get changeTarget;

  /// No description provided for @baseWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Gear and pack only — no food or water'**
  String get baseWeightHint;

  /// No description provided for @removeFromTrip.
  ///
  /// In en, this message translates to:
  /// **'Remove from trip'**
  String get removeFromTrip;

  /// No description provided for @totalWeight.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalWeight;

  /// No description provided for @baseWeight.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get baseWeight;

  /// No description provided for @packingChecklist.
  ///
  /// In en, this message translates to:
  /// **'Packing checklist'**
  String get packingChecklist;

  /// No description provided for @packDone.
  ///
  /// In en, this message translates to:
  /// **'All packed'**
  String get packDone;

  /// No description provided for @packingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tick off what\'s already in your pack'**
  String get packingSubtitle;

  /// No description provided for @emptyInventory.
  ///
  /// In en, this message translates to:
  /// **'Your inventory is empty'**
  String get emptyInventory;

  /// No description provided for @addFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Add your first item'**
  String get addFirstItem;

  /// No description provided for @myInventory.
  ///
  /// In en, this message translates to:
  /// **'My inventory'**
  String get myInventory;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Find an item…'**
  String get searchHint;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get resetAll;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @lightestFirst.
  ///
  /// In en, this message translates to:
  /// **'Lightest first'**
  String get lightestFirst;

  /// No description provided for @heaviestFirst.
  ///
  /// In en, this message translates to:
  /// **'Heaviest first'**
  String get heaviestFirst;

  /// No description provided for @defaultOrder.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultOrder;

  /// No description provided for @showItems.
  ///
  /// In en, this message translates to:
  /// **'Show ({items})'**
  String showItems(String items);

  /// No description provided for @packingFor.
  ///
  /// In en, this message translates to:
  /// **'Packing for: '**
  String get packingFor;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @packingHint.
  ///
  /// In en, this message translates to:
  /// **'Tick off what\'s already in your pack. The list itself is put together with the checkboxes in Inventory.'**
  String get packingHint;

  /// No description provided for @allPacked.
  ///
  /// In en, this message translates to:
  /// **'All packed — ready to go'**
  String get allPacked;

  /// No description provided for @packedProgress.
  ///
  /// In en, this message translates to:
  /// **'{packed} of {total} packed'**
  String packedProgress(int packed, int total);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @tripCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trip} other{{count} trips}}'**
  String tripCount(int count);

  /// No description provided for @allYourGear.
  ///
  /// In en, this message translates to:
  /// **'All your gear'**
  String get allYourGear;

  /// No description provided for @attentionRepair.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs repair} other{{count} items need repair}}'**
  String attentionRepair(int count);

  /// No description provided for @attentionReplace.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item to replace} other{{count} items to replace}}'**
  String attentionReplace(int count);

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sectionData;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get importFromFile;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportExcel;

  /// No description provided for @exportLighterPack.
  ///
  /// In en, this message translates to:
  /// **'Export for LighterPack (CSV)'**
  String get exportLighterPack;

  /// No description provided for @saveToPhone.
  ///
  /// In en, this message translates to:
  /// **'Save to phone'**
  String get saveToPhone;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send…'**
  String get sendTo;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get fileSaved;

  /// No description provided for @colWeightEach.
  ///
  /// In en, this message translates to:
  /// **'Weight each, {unit}'**
  String colWeightEach(String unit);

  /// No description provided for @colWeightTotal.
  ///
  /// In en, this message translates to:
  /// **'Total weight, {unit}'**
  String colWeightTotal(String unit);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get comingSoon;

  /// No description provided for @sectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sectionSettings;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @clearAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get clearAllData;

  /// No description provided for @clearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get clearAllTitle;

  /// No description provided for @clearAllBody.
  ///
  /// In en, this message translates to:
  /// **'All items, categories and trips will be deleted for good. Your settings stay.'**
  String get clearAllBody;

  /// No description provided for @clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get clearAllConfirm;

  /// No description provided for @tripDates.
  ///
  /// In en, this message translates to:
  /// **'Trip dates'**
  String get tripDates;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @tripNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Weekend in the mountains'**
  String get tripNameHint;

  /// No description provided for @datesOptional.
  ///
  /// In en, this message translates to:
  /// **'Dates (optional)'**
  String get datesOptional;

  /// No description provided for @pickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get pickDates;

  /// No description provided for @clearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get clearDates;

  /// No description provided for @targetOptional.
  ///
  /// In en, this message translates to:
  /// **'Target pack weight, {unit} (optional)'**
  String targetOptional(String unit);

  /// No description provided for @startFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get startFrom;

  /// No description provided for @emptyList.
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get emptyList;

  /// No description provided for @listOfTrip.
  ///
  /// In en, this message translates to:
  /// **'List from “{name}”'**
  String listOfTrip(String name);

  /// No description provided for @createTrip.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get createTrip;

  /// No description provided for @noTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get noTrips;

  /// No description provided for @noTripsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a trip to put together its gear list and keep an eye on the weight.'**
  String get noTripsSubtitle;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get myTrips;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive · {n}'**
  String archive(int n);

  /// No description provided for @turnIntoTrip.
  ///
  /// In en, this message translates to:
  /// **'Turn into a trip'**
  String get turnIntoTrip;

  /// No description provided for @deleteTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteTripTitle(String name);

  /// No description provided for @deleteTripBody.
  ///
  /// In en, this message translates to:
  /// **'This trip\'s list will be deleted. The items themselves stay in Inventory.'**
  String get deleteTripBody;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @allTrips.
  ///
  /// In en, this message translates to:
  /// **'All trips'**
  String get allTrips;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
