
import '../data_source/remote/merchant_device_remote_ds.dart';

/// 商家设备仓库。
///
/// 刻意不做内存缓存：token 是"注册那一刻才准"的短生命周期数据，
/// 缓存住反而会拿旧 token 上报，制造脏数据。
abstract class MerchantDeviceRepository {
  /// 上报/更新当前设备的 TPNS token。
  Future<void> registerDevice({
    required String merchantId,
    required String tpnsToken,
    required String platform,
    String? appVersion,
  });

 
}

class MerchantDeviceRepositoryImpl implements MerchantDeviceRepository {
  final MerchantDeviceRemoteDS _remote;

  MerchantDeviceRepositoryImpl({
    required MerchantDeviceRemoteDS remote,
  }) : _remote = remote;

  @override
  Future<void> registerDevice({
    required String merchantId,
    required String tpnsToken,
    required String platform,
    String? appVersion,
  }) {
    return _remote.upsertDevice(
      merchantId: merchantId,
      tpnsToken: tpnsToken,
      platform: platform,
      appVersion: appVersion,
    );
  }

}