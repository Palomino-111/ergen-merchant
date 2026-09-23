import 'package:permission_handler/permission_handler.dart';

// 请求位置权限
Future<PermissionStatus> requestLocationPermission() async {
  return Permission.location.onDeniedCallback(() {
    print("requestLocationPermission, onDeniedCallback");
  }).onGrantedCallback(() {
    print("requestLocationPermission, onGrantedCallback");
  }).onPermanentlyDeniedCallback(() {
    print("requestLocationPermission, onPermanentlyDeniedCallback");
  }).onRestrictedCallback(() {
    print("requestLocationPermission, onRestrictedCallback");
  }).onLimitedCallback(() {
    print("requestLocationPermission, onLimitedCallback");
  }).onProvisionalCallback(() {
    print("requestLocationPermission, onProvisionalCallback");
  }).request();
}

// extension PermissionWithServiceExtension on PermissionWithService {
//   Future<PermissionStatus> request() async {
//     PermissionStatus permissionStatus = await onDeniedCallback(() {
//       print("request, $toString, onDeniedCallback");
//     }).onGrantedCallback(() {
//       print("request, $toString, onGrantedCallback");
//     }).onPermanentlyDeniedCallback(() {
//       print("request, $toString, onPermanentlyDeniedCallback");
//     }).onRestrictedCallback(() {
//       print("request, $toString, onRestrictedCallback");
//     }).onLimitedCallback(() {
//       print("request, $toString, onLimitedCallback");
//     }).onProvisionalCallback(() {
//       print("request, $toString, onProvisionalCallback");
//     }).request();
//     return permissionStatus;
//   }
// }
