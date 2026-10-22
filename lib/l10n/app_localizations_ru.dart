// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navHome => 'Главная';

  @override
  String get navInventory => 'Инвентарь';

  @override
  String get navTrips => 'Походы';

  @override
  String get navProfile => 'Профиль';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get create => 'Создать';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get gotIt => 'Понятно';

  @override
  String get all => 'Все';

  @override
  String nOfM(int n, int m) {
    return '$n из $m';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещей',
      few: '$count вещи',
      one: '$count вещь',
    );
    return '$_temp0';
  }

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count категорий',
      few: '$count категории',
      one: '$count категория',
    );
    return '$_temp0';
  }

  @override
  String quantitySuffix(int n) {
    return '($n шт.)';
  }

  @override
  String get copyWord => 'копия';

  @override
  String get conditionReady => 'Готово к походу';

  @override
  String get conditionNeedsRepair => 'Требует ремонта';

  @override
  String get conditionReplace => 'Под замену';

  @override
  String get packFood => 'Еда';

  @override
  String get packGear => 'Снаряжение';

  @override
  String get packWater => 'Вода';

  @override
  String get seedPacks => 'Рюкзаки';

  @override
  String get seedSleep => 'Спальная система';

  @override
  String get seedKitchen => 'Кухня';

  @override
  String get seedClothing => 'Одежда';

  @override
  String get uncategorized => 'Неразобранное';

  @override
  String get draft => 'Черновик';

  @override
  String get categoryHasChildren =>
      'Сначала удали или перенеси дочерние категории — у этой категории ещё есть вложенные.';

  @override
  String get categoryEmpty => 'Пока пусто';

  @override
  String get addItem => 'Добавить вещь';

  @override
  String takeN(int n) {
    return 'Беру $n';
  }

  @override
  String get categoryNameRequired => 'Введи название категории';

  @override
  String get noCategoriesYetInfo =>
      'Пока нет ни одной категории — создайте первую, и потом сможете сделать её родителем для новых.';

  @override
  String get newCategory => 'Новая категория';

  @override
  String get editCategory => 'Редактировать категорию';

  @override
  String get categoryName => 'Название категории';

  @override
  String get parentCategory => 'Родительская категория';

  @override
  String get noParent => 'Нет (основная категория)';

  @override
  String get section => 'Раздел';

  @override
  String get icon => 'Иконка';

  @override
  String get color => 'Цвет';

  @override
  String get itemNameRequired => 'Введи название вещи';

  @override
  String get weightRequired => 'Укажи вес';

  @override
  String get editItem => 'Редактировать вещь';

  @override
  String get itemName => 'Название вещи';

  @override
  String get weight => 'Вес';

  @override
  String get unitG => 'г';

  @override
  String get unitOz => 'унц.';

  @override
  String get unitKg => 'кг';

  @override
  String get unitLb => 'фнт';

  @override
  String get weightUnits => 'Единицы веса';

  @override
  String get unitsMetric => 'Килограммы';

  @override
  String get unitsImperial => 'Фунты';

  @override
  String get quantity => 'Количество';

  @override
  String weightTotal(String weight) {
    return '= $weight всего';
  }

  @override
  String get category => 'Категория';

  @override
  String get noCategory => 'Без категории';

  @override
  String get createCategory => 'Создать категорию';

  @override
  String get condition => 'Состояние';

  @override
  String get targetWeightTitle => 'Целевой вес рюкзака';

  @override
  String weightIn(String unit) {
    return 'Вес ($unit)';
  }

  @override
  String get clearTargetHint => '0 или пусто — убрать цель';

  @override
  String get emptyPackTitle => 'Твой рюкзак пуст';

  @override
  String get emptyPackSubtitle =>
      'Отметь снаряжение как \"в рюкзаке\" в Инвентаре, чтобы увидеть вес.';

  @override
  String get goToInventory => 'Перейти в Инвентарь';

  @override
  String get setTarget => 'Задать целевой вес';

  @override
  String get changeTarget => 'Изменить целевой вес';

  @override
  String get baseWeightHint =>
      'Только снаряжение и рюкзак — без еды, воды и того, что надето';

  @override
  String wornOnYou(String weight) {
    return '+ $weight надето на тебе';
  }

  @override
  String get wornLabel => 'Надето на мне';

  @override
  String get wornHint =>
      'Обувь, куртка, в которой идёшь, — не входит в вес рюкзака';

  @override
  String get wornTag => 'надето';

  @override
  String get wornColumn => 'Надето';

  @override
  String get yes => 'да';

  @override
  String get removeFromTrip => 'Убрать из похода';

  @override
  String get totalWeight => 'Общий вес';

  @override
  String get baseWeight => 'Базовый';

  @override
  String get packingChecklist => 'Чек-лист сборов';

  @override
  String get packDone => 'Рюкзак собран';

  @override
  String get packingSubtitle => 'Отмечай, что уже лежит в рюкзаке';

  @override
  String get emptyInventory => 'Твой инвентарь пуст';

  @override
  String get addFirstItem => 'Добавить первую вещь';

  @override
  String get myInventory => 'Мой инвентарь';

  @override
  String get searchHint => 'Найти вещь…';

  @override
  String get nothingFound => 'Ничего не нашлось';

  @override
  String get filters => 'Фильтры';

  @override
  String get resetAll => 'Сбросить всё';

  @override
  String get sort => 'Сортировка';

  @override
  String get lightestFirst => 'Сначала лёгкие';

  @override
  String get heaviestFirst => 'Сначала тяжёлые';

  @override
  String get defaultOrder => 'По умолчанию';

  @override
  String showItems(String items) {
    return 'Показать ($items)';
  }

  @override
  String get packingFor => 'Собираю для: ';

  @override
  String get startOver => 'Начать заново';

  @override
  String get packingHint =>
      'Отмечай, что уже лежит в рюкзаке. Сам список вещей собирается галочками в Инвентаре.';

  @override
  String get allPacked => 'Всё уложено, можно в путь';

  @override
  String packedProgress(int packed, int total) {
    return '$packed из $total уложено';
  }

  @override
  String get profile => 'Профиль';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String tripCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count походов',
      few: '$count похода',
      one: '$count поход',
    );
    return '$_temp0';
  }

  @override
  String get allYourGear => 'Весь инвентарь';

  @override
  String attentionRepair(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещей требуют ремонта',
      few: '$count вещи требуют ремонта',
      one: '$count вещь требует ремонта',
    );
    return '$_temp0';
  }

  @override
  String attentionReplace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещей под замену',
      few: '$count вещи под замену',
      one: '$count вещь под замену',
    );
    return '$_temp0';
  }

  @override
  String get sectionData => 'Данные';

  @override
  String get importFromFile => 'Импорт из файла';

  @override
  String get exportExcel => 'Экспорт в Excel';

  @override
  String get exportLighterPack => 'Экспорт для LighterPack (CSV)';

  @override
  String get importTitle => 'Импорт';

  @override
  String get importMappingTitle => 'Что в какой колонке?';

  @override
  String get importMappingHint =>
      'Мы угадали, что смогли, — проверь и поправь. Обязательны название и вес.';

  @override
  String get fieldUnit => 'Единица веса';

  @override
  String get fieldConsumable => 'Расходник';

  @override
  String get defaultUnit => 'Если единица не указана';

  @override
  String get columnNone => '— нет —';

  @override
  String columnN(int n) {
    return 'Колонка $n';
  }

  @override
  String get importExample => 'Пример';

  @override
  String get next => 'Дальше';

  @override
  String newCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых категорий',
      few: '$count новые категории',
      one: '$count новая категория',
    );
    return '$_temp0';
  }

  @override
  String skippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count строк пропущено',
      few: '$count строки пропущены',
      one: '$count строка пропущена',
    );
    return '$_temp0 — нет названия или веса';
  }

  @override
  String duplicatesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вещей уже есть в инвентаре',
      few: '$count вещи уже есть в инвентаре',
      one: '$count вещь уже есть в инвентаре',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesSkip => 'Пропустить их';

  @override
  String get duplicatesAdd => 'Добавить копии';

  @override
  String get alreadyHave => 'уже есть';

  @override
  String importButton(String items) {
    return 'Импортировать ($items)';
  }

  @override
  String get nothingToImport => 'Нечего импортировать';

  @override
  String get adjustColumns => 'Настроить колонки';

  @override
  String importDone(String items) {
    return 'Добавлено: $items';
  }

  @override
  String get importReadError =>
      'Не получилось прочитать файл. Подойдут .csv и .xlsx — старый .xls можно пересохранить в Excel как .xlsx.';

  @override
  String get saveToPhone => 'Сохранить на телефон';

  @override
  String get sendTo => 'Отправить…';

  @override
  String get fileSaved => 'Файл сохранён';

  @override
  String colWeightEach(String unit) {
    return 'Вес за шт., $unit';
  }

  @override
  String colWeightTotal(String unit) {
    return 'Вес всего, $unit';
  }

  @override
  String get sectionSettings => 'Настройки';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String version(String version) {
    return 'Версия $version';
  }

  @override
  String get clearAllData => 'Очистить все данные';

  @override
  String get clearAllTitle => 'Удалить все данные?';

  @override
  String get clearAllBody =>
      'Все вещи, категории и походы удалятся безвозвратно. Настройки останутся.';

  @override
  String get clearAllConfirm => 'Удалить всё';

  @override
  String get tripDates => 'Даты похода';

  @override
  String get editTrip => 'Редактировать поход';

  @override
  String get newTrip => 'Новый поход';

  @override
  String get name => 'Название';

  @override
  String get tripNameHint => 'Например, Карелия на выходные';

  @override
  String get datesOptional => 'Даты (необязательно)';

  @override
  String get pickDates => 'Выбрать даты';

  @override
  String get clearDates => 'Убрать даты';

  @override
  String targetOptional(String unit) {
    return 'Целевой вес рюкзака, $unit (необязательно)';
  }

  @override
  String get startFrom => 'Начать с';

  @override
  String get emptyList => 'Пустой список';

  @override
  String listOfTrip(String name) {
    return 'Список похода «$name»';
  }

  @override
  String get createTrip => 'Создать поход';

  @override
  String get noTrips => 'Походов пока нет';

  @override
  String get noTripsSubtitle =>
      'Создай поход, чтобы собрать для него свой список вещей и следить за весом.';

  @override
  String get myTrips => 'Мои походы';

  @override
  String archive(int n) {
    return 'Архив · $n';
  }

  @override
  String get turnIntoTrip => 'Превратить в поход';

  @override
  String deleteTripTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteTripBody =>
      'Список вещей этого похода удалится. Сами вещи останутся в Инвентаре.';

  @override
  String get active => 'Активный';

  @override
  String get allTrips => 'Все походы';
}
