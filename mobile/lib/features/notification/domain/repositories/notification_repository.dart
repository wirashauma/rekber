import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<Either<Failure, List<NotificationEntity>>> getNotifications({
    String? cursor,
    int limit = 20,
  });

  Future<Either<Failure, int>> getUnreadCount();

  Future<Either<Failure, NotificationEntity>> markAsRead(String notificationId);

  Future<Either<Failure, int>> markAllAsRead();
}
