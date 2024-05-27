import 'dart:io';

/// 根据图片自动生成资源文件索引
///
/// 脚本的配置信息
/// 使用前一定一定要记得检查脚本配置
/// 注意 注意 ！！！
///
/// flutterProjectPath 和 resourcePath 一定一定要配置 ！！！
///
/// 注意 注意 ！！！
///
///

final flutterProjectPath = '/Users/light/IdeaProjects/AnswerPlanet';
final resourcePath = '$flutterProjectPath/lib/resources';
final rPath = '$resourcePath/R.dart';
final imagePath = '$resourcePath/Image.dart';
void main(List<String> arguments) async {
  createIndexFile();
}

/// 创建R文件
/// 创建imageIndex文件
String imageString = '';
final String imageClass = 'class Image {\n\n}';
final String imageImport = 'import \'Image.dart\';\n\n';
final String imageDesc = '///这里存放的是扫描图片文件夹生成的图片路径\n';

String rString = '';
final String rDesc =
    '/// 资源文件类由ide自动生成\n/// ide自动生成的资源文件类有\n/// R , Font , Icon , Image , Raw\n/// Color , Dimens , Paddings , Strings , Theme 由用户手动编辑\n';
final String rClass = 'class R {\n  static Image image = Image();\n}';
void createIndexFile() {
  // 读取Image文件
  File imageFile = File(imagePath);
  imageFile.createSync(recursive: true);
  if (imageFile.existsSync()) {
    imageString = imageFile.readAsStringSync();
  }
  if (imageString.trim() == '') {
    imageString = imageDesc + imageClass;
    imageFile
        .writeAsString(imageString)
        .then((_) => print('Image.dart 创建成功'))
        .catchError((error) => print('Image.dart 创建失败: $error'));
  }

  // 读取R文件
  File rFile = File(rPath);
  rFile.createSync(recursive: true);
  if (rFile.existsSync()) {
    rString = rFile.readAsStringSync();
  }
  if (rString.trim() == '') {
    rString = imageImport + rDesc + rClass;
    rFile
        .writeAsString(rString)
        .then((_) => print('R.dart 创建成功'))
        .catchError((error) => print('R.dart 创建失败: $error'));
  }
}
