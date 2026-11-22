import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiService apiService;

  NotificationRepositoryImpl({required this.apiService});

  @override
  Future<Either<Failure, List<NotificationEntity>>> getNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final endpoint = '/notifications${queryString.isNotEmpty ? '?$queryString' : ''}';

      final response = await apiService.get(endpoint);
      if (response != null && response['success'] == true && response['data'] is List) {
        final list = (response['data'] as List)
            .map((item) => NotificationEntity.fromJson(item as Map<String, dynamic>))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final response = await apiService.get('/notifications/unread-count');
      if (response != null && response['success'] == true && response['data'] != null) {
        final count = response['data']['unreadCount'] ?? 0;
        return Right((count as num).toInt());
      }
      return const Right(0);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, NotificationEntity>> markAsRead(String notificationId) async {
    try {
      final response = await apiService.post('/notifications/$notificationId/read', {});
      if (response != null && response['success'] == true && response['data'] != null) {
        return Right(NotificationEntity.fromJson(response['data'] as Map<String, dynamic>));
      }
      return const Left(ServerFailure(message: 'Gagal menandai notifikasi telah dibaca.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async {
    try {
      final response = await apiService.post('/notifications/read-all', {});
      if (response != null && response['success'] == true) {
        final updatedCount = response['data']?['count'] ?? 0;
        return Right((updatedCount as num).toInt());
      }
      return const Right(0);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
