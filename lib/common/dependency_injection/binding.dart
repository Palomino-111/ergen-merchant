import 'package:get/get.dart';
import '../data/data_source/cache/meal_cache_ds.dart';
import '../data/data_source/remote/meal_remote_ds.dart';
import '../data/repository/meal_repository.dart';

class RepositoryBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MealRemoteDS>(() => MealRemoteDSImpl());
    Get.lazyPut<MealCacheDS>(() => MealCacheDSImpl());
    Get.lazyPut<MealRepository>(
      () => MealRepositoryImpl(
        remote: Get.find(),
        cache: Get.find(),
      ),
    );
  }
}
