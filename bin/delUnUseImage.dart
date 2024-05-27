import 'dart:io';

import 'helpers/console.dart';
import 'helpers/helpers.dart';

/// 脚本的配置信息
/// 使用前一定一定要记得检查脚本配置
/// 注意 注意 ！！！
///
/// flutterProjectPath 和 ignoreDirectories 一定一定要配置 ！！！
///
/// 注意 注意 ！！！

/// 是否展示日志
bool isShowLog = true;

/// 是否对扫描出的未使用的资源文件进行删除操作
bool isDeleteUnUsedAsserts = true;

/// 被扫的功能根目录
/// final flutterProjectPath = Directory.current.path;
/// final flutterProjectPath = '/Users/light/IdeaProjects/AnswerPlanet';
final flutterProjectPath = '/Users/light/IdeaProjects/AnswerPlanet';

///资源文件夹
String assetsFolderPath = '$flutterProjectPath/lib/resources/images';

///iamgeNames.dart所在的文件夹
String imageNamesPath = '$flutterProjectPath/lib/common/imageNames.dart';

///被删除后的资源存放位置
String deletedAssetFolderName = '$flutterProjectPath/deleted_assets';

/// 忽略，不被脚本扫的文件夹
final ignoreDirectories = [
  assetsFolderPath,
  deletedAssetFolderName,
  'assets',
  'android',
  'build',
  'ios',
  'web',
  '.dart_tool',
  '.git',
  '.gradle',
  'plugin',
  'resources',
  'deleted_assets',
];

/// 脚本优化
/// 先全局扫 imageNames.dart
/// 删除 imageNames.dart 里的相关记录
/// 全局扫删除无用记录
void main(List<String> arguments) async {
  File imageNamesFile = File(imageNamesPath);
  if (imageNamesFile.existsSync()) {
    imageNamesString = imageNamesFile.readAsStringSync();
    if (imageNamesString == '') {
      write('找不到文件 imageNames.dart ', colorType: ConsoleColorType.error);
      return;
    }
  } else {
    write('找不到文件 imageNames.dart ', colorType: ConsoleColorType.error);
    return;
  }

  /// 资源文件
  assetsFiles =
      Helpers.getFilesNameWithPath(Directory(assetsFolderPath), true, {});
  dealImageNames();
}

String currentTime = '';
void dealImageNames() {
  /// 对imageNames.dart进行备份
  DateTime now = DateTime.now();
  currentTime =
      '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
  File imageNamesBak =
      File('$deletedAssetFolderName/$currentTime/imageNames.dart.bak');
  imageNamesBak.createSync(recursive: true);
  imageNamesBak
      .writeAsString(imageNamesString)
      .then((_) => print('imageNames.dart 备份成功'))
      .catchError((error) => print('imageNames.dart 备份失败: $error'));
  projectFiles = Helpers.getFilesNameWithPath(
    Directory(flutterProjectPath),
    false,
    {},
    ignoreDirectories: ignoreDirectories,
  );
  scanImageNames();
  delFromImageNames();
  delUnusedImage();
}

///对ImgeNames.dart进行扫描
/// 这里要扫描出 unUsedFilePath , unUsedSpecialPath , itemRecords , specialPath
void scanImageNames() {
  RegExp regex =
      RegExp(r"static const String \w+ =\s?\n?\s*\w+ \+ '/\S+\.png';");
  Iterable<Match> matches = regex.allMatches(imageNamesString); // 找出所有匹配项
  for (Match match in matches) {
    matchRows.add(match.group(0) ?? '');
    if (isShowLog) print('找到匹配: ${match.group(0)}');
  }

  RegExp resultExp = RegExp(r"static const .* =\s?\n?\s*.*;");
  Iterable<Match> resultMatches = resultExp.allMatches(imageNamesString);
  for (Match match in resultMatches) {
    allRows.add(match.group(0) ?? '');
    if (!matchRows.contains(match.group(0) ?? '')) {
      unMatchRows.add(match.group(0) ?? '');
    }
    if (isShowLog) print('匹配的变量: ${match.group(0)}');
  }

  matchRows.remove('');
  unMatchRows.remove('');

  print('开始对特殊记录进行处理');
  for (String item in unMatchRows) {
    if (item.contains("lib/resources")) {
      if (!item.contains('.')) {
        // 资源文件夹路径
        RegExp regExp = RegExp(
            r"(static|const)\s+String\s+([a-zA-Z_]\w*)\s*=\s*'([^;]+)';");
        Match? match = regExp.firstMatch(item);
        if (match != null) {
          String variableName = match.group(2) ?? '';
          String variableValue = match.group(3) ?? '';
          assertPath[variableName] = variableValue;
        }
      } else {
        // 资源文件绝对路径
        RegExp regExp = RegExp(
            r"(static|const)\s+String\s+([a-zA-Z_]\w*)\s*=\s*'([^;]+)';");
        Match? match = regExp.firstMatch(item);
        if (match != null) {
          String variableName = match.group(2) ?? '';
          String variableValue = match.group(3) ?? '';
          filePath[variableName] = variableValue;
          itemRecords[variableName] = item;
          if (isShowLog) {
            print(
                "样本记录/从资源文件绝对路径提取 , key: $variableName , value: $variableValue ");
          }
        }
      }
    } else {
      filePath[getvariableName(item)] = getVariableValue(item, assertPath);
      itemRecords[getvariableName(item)] = item;
      if (isShowLog) {
        print(
            "样本记录/匹配到的特殊记录提取 , key: ${getvariableName(item)} , value: ${getVariableValue(item, assertPath)} ");
      }
    }
  }

  ///对匹配到的每一行进行处理
  /// 1. 提取key
  /// 2. 转化文件路径
  print('开始对每一条记录进行提取');
  print('----------------------------------');
  for (String item in matchRows) {
    filePath[getvariableName(item)] = getVariableValue(item, assertPath);
    itemRecords[getvariableName(item)] = item;
    if (isShowLog) {
      print(
          "样本记录/从匹配到的资源记录提取 , key: ${getvariableName(item)} , value: ${getVariableValue(item, assertPath)} ");
    }
  }

  print('处理未匹配到的特殊样本,如果不做处理会误删');

  ///处理特殊样本1
  RegExp regex1 = RegExp(r'static String \w+\(\w+ \w+\) \{[\s\S]*?\}');
  Iterable<Match> matches1 = regex1.allMatches(imageNamesString);
  for (Match match in matches1) {
    String matchStr = match.group(0) ?? '';
    specialRows.add(matchStr);
    String special1VariableName = getSpecial1VariableName(matchStr);
    // print('提取到特殊样本1 的方法名 $special1VariableName');
    RegExp valueRegex = RegExp(r"\S+ \+ '/\S+\.png'");
    Iterable<Match> valueMatches = valueRegex.allMatches(matchStr);
    //放提取的资源
    final reSource = <String>{};
    for (Match match in valueMatches) {
      // print('提取前 ' + (match.group(0) ?? ''));
      // print('提取到特殊样本1 的资源: $strValue');
      reSource.add(getVariableValue(match.group(0) ?? '', assertPath));
    }
    specialPath[special1VariableName] = reSource;
    itemRecords[special1VariableName] = matchStr;
    if (isShowLog) {
      print('样本记录/从特殊样本1提取 ，key: $special1VariableName , value: $reSource');
    }
  }
  // print('特殊样本1资源提取完毕 $specialPath');

  ///处理特殊样本2
  RegExp regex2 = RegExp(r'static const List<String> \w+ = \[[\s\S]*?\];');
  Iterable<Match> matches2 = regex2.allMatches(imageNamesString);
  for (Match match in matches2) {
    String matchStr = match.group(0) ?? '';
    specialRows.add(matchStr);
    // print('匹配到的样本资源2:\n' + matchStr);
    String special2VariableName = getSpecial2VariableName(matchStr);
    // print('提取到特殊样本2 的资源名 $special2VariableName');
    RegExp valueRegex = RegExp(r"\S+ \+ '/\S+\.png'");
    Iterable<Match> valueMatches = valueRegex.allMatches(matchStr);
    //放提取的资源
    final reSource = <String>{};
    for (Match match in valueMatches) {
      // print('提取前 ' + (match.group(0) ?? ''));
      // print('提取到特殊样本2 的资源: $strValue');
      reSource.add(getVariableValue(match.group(0) ?? '', assertPath));
    }
    specialPath[special2VariableName] = reSource;
    itemRecords[special2VariableName] = matchStr;
    if (isShowLog) {
      print('样本记录/从特殊样本2提取 ，key: $special2VariableName , value: $reSource');
    }
  }
  print('特殊样本资源提取完毕 $specialPath');

  print('开始扫描项目文件,判断图片是否被引用');
  final Map<String, String> usedFilePath = {};
  final Map<String, Set<String>> usedSpecialPath = {};

  /// 扫描项目文件，判断资源是否被引用
  ///判断 imageNames.xxxx 的变量名有没有被使用
  ///被使用则加入到 usedFilePath(变量)或usedSpecialPath(数组，方法等等) 中
  print('开始扫描项目文件,判断图片是否被引用');
  final projectFilesPaths = projectFiles.values;
  for (final path in projectFilesPaths) {
    if (isShowLog) {
      print('扫描项目文件: $path , 判断imageNames.dart 被引用的情况');
    }
    final fileString = Helpers.tryDo(
          () => File(path).readAsStringSync(),
          orElse: (__, _) => '',
        ) ??
        '';
    for (String key in filePath.keys) {
      if (matchKey(fileString, key)) {
        usedFilePath[key] = filePath[key] ?? '';
      }
    }

    for (String mKey in specialPath.keys) {
      String key = mKey;
      if (mKey.contains('(')) {
        key = mKey.replaceFirst('(', '');
      }
      if (mKey.contains('[')) {
        key = mKey.replaceFirst('[', '');
      }
      if (matchKey(fileString, key)) {
        usedSpecialPath[key] = specialPath[mKey] ?? {};
      }
    }
  }

  /// 扫描目录，得出的扫描结果
  filePath.forEach((key, value) {
    if (!usedFilePath.containsKey(key)) {
      unUsedFilePath[key] = value;
    }
  });

  specialPath.forEach((key, value) {
    if (!usedSpecialPath.containsKey(key)) {
      unUsedSpecialPath[key] = value;
    }
  });

  if (isShowLog) {
    for (String key in unUsedFilePath.keys) {
      print(
          '未在项目中使用的资源 key: $key , value: ${unUsedFilePath[key]} , record: ${itemRecords[key]}');
    }
  }
}

/// 从Imagenames.dart中删除无用记录
void delFromImageNames() {
  File recordFile = File('$deletedAssetFolderName/$currentTime/records');
  recordFile.createSync(recursive: true);
  File logFile = File('$deletedAssetFolderName/$currentTime/log');
  var logSink = logFile.openWrite();
  var recordSink = recordFile.openWrite();

  for (String key in unUsedFilePath.keys) {
    write(
        '删除文件 key: $key value: ${unUsedFilePath[key]} \n record: ${itemRecords[key]}\n',
        colorType: ConsoleColorType.info);

    ///删除 imageNames.darth中的记录
    if (itemRecords[key] != null) {
      imageNamesString =
          imageNamesString.replaceFirst('  ${itemRecords[key]!}\n', '');
    }

    ///处理日志
    logSink.write(
        '删除文件\n key: $key \n value: ${unUsedFilePath[key]} \n record: ${itemRecords[key]}\n\n');
    recordSink.write('${itemRecords[key]}\n');
  }

  Set<String> unUsedSpecialPathData = {};

  ///imageNames.dart中数组和方法的处理
  for (String key in unUsedSpecialPath.keys) {
    write(
        '删除文件 key: $key , value: ${unUsedSpecialPath[key]} \n record: ${itemRecords[key]}\n',
        colorType: ConsoleColorType.info);

    ///删除 imageNames.darth中的记录
    if (itemRecords[key] != null) {
      imageNamesString =
          imageNamesString.replaceFirst('  ${itemRecords[key]!}\n', '');
    }
    if (unUsedSpecialPath[key] != null) {
      logSink.write('删除文件\n key: $key \n ');
      logSink.write('value:\n ');
      for (String fileKey in unUsedSpecialPath[key]!) {
        unUsedSpecialPathData.add(fileKey);
        logSink.write('    $fileKey \n ');
      }
      logSink.write('record: ${itemRecords[key]}\n\n');
    }
    recordSink.write('${itemRecords[key]}\n');
  }

  recordSink.close();
  logSink.close();
  File imageNamesFile = File(imageNamesPath);
  imageNamesFile
      .writeAsString(imageNamesString)
      .then((_) => print('imageNames.dart 写入成功'))
      .catchError((error) => print('imageNames.dart 写入失败: $error'));
}

///打印最后的输出结果
void printResult() {
  write('资源文件夹路径 $assertPath');
  write(
      'imageNames.dart中有${unUsedSpecialPath.length + unUsedSpecialPath.length} 条记录未被引用');
  write('imageNames.dart中一共有${allRows.length} 条记录');
  write(
      '被删除的资源没有被真正的删除哦，他们被存放在了 deleted_assets 目录下，要恢复资源可以根据 deleted_assets 下的日志进行恢复 \n',
      colorType: ConsoleColorType.attention);
  write('未项目文件引用到的资源文件数: $unUsedAssetsCount,工程资源文件数: $assetsFilesCount\n',
      colorType: ConsoleColorType.attention);
  write('imageNames.dart未在工程中使用的变量共$unUsedImgCount个 , 使用中的变量共$allImgCount个\n',
      colorType: ConsoleColorType.attention);
}

bool matchKey(String content, String key) {
  RegExp regExp = RegExp(r'ImageNames\s*\.' + key);
  return regExp.hasMatch(content);
}

// 项目文件
Map<String, String> projectFiles = {};
//资源文件夹
Map<String, String> assetsFiles = {};
// 工程资源文件数
int assetsFilesCount = 0;
// 被项目文件引用到到资源文件数
int usedAssetsCount = 0;
// 没被项目文件引用到的资源文件数
int unUsedAssetsCount = 0;
//没有被项目直接引用的资源文件
Iterable<String> unUsedAssetsPaths = {};
//imageNames.dart未引用的资源目录
final unUsedFilePath = <String, String>{};
// imageNames.dart中所有的变量
final allRows = <String>{};
// imageNames.dart中所有符合的规则的变量
// static const String popLiveText_zh = imageBasePath + '/popLiveText_zh.png';
final matchRows = <String>{};
// imageNames.dart中不符合的规则的变量
final unMatchRows = <String>{};
// imageNames.dart中特殊的变量(数组，方法等)
final specialRows = <String>{};
// 资源文件夹路径
final Map<String, String> assertPath = {};
final Map<String, String> filePath = {};

final Map<String, String> itemRecords = {};
final Map<String, Set<String>> specialPath = {};
final Map<String, Set<String>> unUsedSpecialPath = {};
// imageNames.dart中没有被引用到的文件数
int unUsedImgCount = 0;
// imageNames.dart中所有的文件数
int allImgCount = 0;
String imageNamesString = '';

String getSpecial1VariableName(String matchStr) {
  RegExp regExp = RegExp(r'static String\s+(\w+)\s*\(.*?\)\s*{');
  Match? match = regExp.firstMatch(matchStr);
  return match?.group(1) ?? '';
}

String getSpecial2VariableName(String matchStr) {
  RegExp regExp = RegExp(r'static const List<String> (\S+) =');
  Match? match = regExp.firstMatch(matchStr);
  return match?.group(1) ?? '';
}

String getvariableName(String item) {
  RegExp regex = RegExp(r"static const String (\S+) =");
  Match? match = regex.firstMatch(item);
  String variableName = match?.group(1) ?? '';
  return variableName;
}

String getVariableValue(String contentData, Map<String, String> assertPath) {
  /// 提取出资源文件夹路径
  String assertDicPath = '';
  for (String item in assertPath.keys) {
    if (contentData.contains(item)) {
      assertDicPath = assertPath[item] ?? '';
      break;
    }
  }
  // print('assertDicPath: $assertDicPath ');
  RegExp regex = RegExp(r"/(\S+\.[a-zA-Z]+)");
  Match? match = regex.firstMatch(contentData);
  String variableValue = match?.group(1) ?? '';
  String filePath = "$assertDicPath/$variableValue";
  // print('getVariableValue: $filePath ');
  return '$flutterProjectPath/$filePath';
}

/// 删除无用的文件
void delUnusedImage() async {
  try {
    final usedAssetsNames = <String>{};

    final assetsFilesNames = assetsFiles.keys;
    final assetsFilesNamesWithoutAlreadyUsed = assetsFilesNames.where(
      (element) => !usedAssetsNames.contains(element),
    );
    for (final assetFileName in assetsFilesNamesWithoutAlreadyUsed) {
      if (imageNamesString.contains(assetFileName)) {
        usedAssetsNames.add(assetFileName);
      }
    }

    print('项目文件扫描结束');

    /// 扫描项目文件，得出的扫描结果
    final unUsedAssets = assetsFiles.entries
        .where((element) => !usedAssetsNames.contains(element.key));
    final unUsedAssetsNames = unUsedAssets.map((asset) => asset.key);
    final unUsedAssetsPaths = unUsedAssets.map((asset) => asset.value);

    assetsFilesCount = assetsFiles.length;
    unUsedAssetsCount = unUsedAssetsNames.length;

    Helpers.deleteFilesByPaths(
      paths: unUsedAssetsPaths,
      assetFolderName: assetsFolderPath,
      deletedAssetFolderName: '$deletedAssetFolderName/$currentTime/files',
    );
  } on Exception catch (e) {
    stdout.addError('$e');
  }
}
