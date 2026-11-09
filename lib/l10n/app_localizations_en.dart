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
  String get baseWeightHint =>
      'Gear and pack only — no food, water or what you wear';

  @override
  String wornOnYou(String weight) {
    return '+ $weight worn';
  }

  @override
  String get wornLabel => 'Worn';

  @override
  String get wornHint =>
      'Boots, the jacket you hike in — not counted in the pack weight';

  @override
  String get wornTag => 'worn';

  @override
  String get wornColumn => 'Worn';

  @override
  String get yes => 'Yes';

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
  String tripCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trips',
      one: '1 trip',
    );
    return '$_temp0';
  }

  @override
  String get allYourGear => 'All your gear';

  @override
  String attentionRepair(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need repair',
      one: '1 item needs repair',
    );
    return '$_temp0';
  }

  @override
  String attentionReplace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items to replace',
      one: '1 item to replace',
    );
    return '$_temp0';
  }

  @override
  String get sectionData => 'Data';

  @override
  String get importFromFile => 'Import from file';

  @override
  String get exportExcel => 'Export to Excel';

  @override
  String get exportLighterPack => 'Export for LighterPack (CSV)';

  @override
  String get importTitle => 'Import';

  @override
  String get importMappingTitle => 'Which column is what?';

  @override
  String get importMappingHint =>
      'We guessed what we could — check and fix it. Name and weight are required.';

  @override
  String get fieldUnit => 'Weight unit';

  @override
  String get fieldConsumable => 'Consumable';

  @override
  String get defaultUnit => 'When no unit is given';

  @override
  String get columnNone => '— none —';

  @override
  String columnN(int n) {
    return 'Column $n';
  }

  @override
  String get importExample => 'Example';

  @override
  String get next => 'Next';

  @override
  String newCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new categories',
      one: '1 new category',
    );
    return '$_temp0';
  }

  @override
  String skippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows skipped',
      one: '1 row skipped',
    );
    return '$_temp0 — no name or weight';
  }

  @override
  String duplicatesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are already in your inventory',
      one: '1 item is already in your inventory',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesSkip => 'Skip them';

  @override
  String get duplicatesAdd => 'Add copies';

  @override
  String get alreadyHave => 'already there';

  @override
  String importButton(String items) {
    return 'Import ($items)';
  }

  @override
  String get nothingToImport => 'Nothing to import';

  @override
  String get adjustColumns => 'Adjust columns';

  @override
  String importDone(String items) {
    return 'Added: $items';
  }

  @override
  String get importReadError =>
      'Couldn\'t read the file. Use .csv or .xlsx — an old .xls can be saved as .xlsx in Excel.';

  @override
  String get saveToPhone => 'Save to phone';

  @override
  String get sendTo => 'Send…';

  @override
  String get fileSaved => 'File saved';

  @override
  String colWeightEach(String unit) {
    return 'Weight each, $unit';
  }

  @override
  String colWeightTotal(String unit) {
    return 'Total weight, $unit';
  }

  @override
  String get sectionSettings => 'Settings';

  @override
  String get sectionAbout => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get clearAllData => 'Delete all data';

  @override
  String get clearAllTitle => 'Delete all data?';

  @override
  String get clearAllBody =>
      'All items, categories and trips will be deleted for good. Your settings stay.';

  @override
  String get clearAllConfirm => 'Delete everything';

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

  @override
  String get signInOrCreate => 'Sign in or create an account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signedOut =>
      'Signed out. Your gear and trips are still on this phone.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'The account and everything stored in the cloud will be deleted for good. Gear and trips on this phone stay.';

  @override
  String get passwordToConfirm => 'Password to confirm';

  @override
  String get deleteAccountConfirm => 'Delete';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get registerTitle => 'Create account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordRule => 'At least 8 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get registerButton => 'Create account';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noAccountYet => 'No account yet?';

  @override
  String get registerLink => 'Create one';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String signedInAs(Object email) {
    return 'Signed in as $email';
  }

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetIntro =>
      'We\'ll email you a 6-digit code to set a new password with.';

  @override
  String get sendCode => 'Send code';

  @override
  String codeSentTo(Object email) {
    return 'We sent a code to $email. Not there? Check your spam folder.';
  }

  @override
  String get code => 'Code from the email';

  @override
  String get newPassword => 'New password';

  @override
  String get saveAndSignIn => 'Save and sign in';

  @override
  String get resendCode => 'Send the code again';

  @override
  String resendIn(Object seconds) {
    return 'Send again in ${seconds}s';
  }

  @override
  String get pleaseWait => 'One moment…';

  @override
  String get errorInvalidCredentials => 'Wrong email or password';

  @override
  String get errorEmailTaken =>
      'An account with this email already exists — try signing in';

  @override
  String get errorInvalidEmail => 'Check the email address';

  @override
  String get errorPasswordTooShort =>
      'The password needs at least 8 characters';

  @override
  String get errorInvalidCode =>
      'The code is wrong or has expired — request a new one';

  @override
  String get errorWrongPassword => 'Wrong password';

  @override
  String get errorTooManyAttempts => 'Too many attempts. Try again in a minute';

  @override
  String get errorNoConnection =>
      'Can\'t reach the server. Check your connection';

  @override
  String get errorMailUnavailable =>
      'Can\'t send email right now. Try again later';

  @override
  String get errorGeneric => 'Something went wrong. Please try again';

  @override
  String get errorEnterPassword => 'Enter your password';

  @override
  String get errorCodeDigits => 'The code has 6 digits';

  @override
  String get confirmEmailTitle => 'Confirm your email';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get changeEmail => 'Change email';

  @override
  String get displayName => 'What should we call you';

  @override
  String get nameHint => 'Name';

  @override
  String get nameOptional => 'Optional. You can leave it empty.';

  @override
  String get addName => 'Add your name';

  @override
  String get syncing => 'Syncing…';

  @override
  String syncedAt(String time) {
    return 'Synced at $time';
  }

  @override
  String get syncOffline => 'Offline — will sync later';

  @override
  String get syncFailed => 'Couldn’t sync — will try again later';

  @override
  String get howManyToTake => 'How many to take?';

  @override
  String takeAll(int n) {
    return 'Take all ($n)';
  }

  @override
  String get saveChangesTitle => 'Save changes?';

  @override
  String get dontSave => 'Don’t save';

  @override
  String get moreActions => 'More';

  @override
  String get draftNameNote => 'Give the draft a name to turn it into a trip.';

  @override
  String get selectTrip => 'Choose';

  @override
  String deleteItemTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get cantBeUndone => 'This can’t be undone.';

  @override
  String get dontAskAgain => 'Don’t ask again';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete the “$name” category?';
  }

  @override
  String get deleteCategoryBody =>
      'Its gear stays in your inventory, under Unsorted.';

  @override
  String get askBeforeDeletingItems => 'Ask before deleting an item';

  @override
  String get no => 'No';
}
