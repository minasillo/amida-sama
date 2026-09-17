import 'package:amidakuji_app/gen/assets.gen.dart';

enum CoupleRole {
  groom(roleName: '阿弥陀'),
  bride(roleName: '如来'),
  ;

  const CoupleRole({required this.roleName});

  final String roleName;

  String get winningImagePath {
    return switch (this) {
      CoupleRole.groom => Assets.beer.path,
      CoupleRole.bride => Assets.chocolate.path,
    };
  }
}
