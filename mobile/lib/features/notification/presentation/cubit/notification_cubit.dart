import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository repository;

  NotificationCubit({required this.repository}) : super(NotificationInitial());

  List<NotificationEntity> _notifications = [];
  int _unreadCount = 0;

  List<NotificationEntity> get currentNotifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications({bool refresh = false}) async {
    if (state is! NotificationLoaded || refresh) {
      emit(NotificationLoading());
    }

    final notifResult = await repository.getNotifications(limit: 30);
    final countResult = await repository.getUnreadCount();

    countResult.fold(
      (_) {},
      (count) => _unreadCount = count,
    );

    notifResult.fold(
      (failure) => emit(NotificationError(failure.message)),
      (list) {
        _notifications = list;
        emit(NotificationLoaded(
          notifications: _notifications,
          unreadCount: _unreadCount,
          hasMore: list.length >= 30,
        ));
      },
    );
  }

  Future<void> loadUnreadCount() async {
    final result = await repository.getUnreadCount();
    result.fold(
      (_) {},
      (count) {
        _unreadCount = count;
        if (state is NotificationLoaded) {
          final loaded = state as NotificationLoaded;
          emit(loaded.copyWith(unreadCount: count));
        }
      },
    );
  }

  Future<void> markAsRead(String id) async {
    if (_notifications.isEmpty && state is NotificationLoaded) {
      _notifications = List.from((state as NotificationLoaded).notifications);
      _unreadCount = (state as NotificationLoaded).unreadCount;
    }

    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(readAt: DateTime.now());
      if (_unreadCount > 0) _unreadCount--;
      if (state is NotificationLoaded) {
        emit(NotificationLoaded(
          notifications: List.from(_notifications),
          unreadCount: _unreadCount,
        ));
      }
    }

    final result = await repository.markAsRead(id);
    result.fold(
      (_) => loadNotifications(refresh: false),
      (updated) {
        final i = _notifications.indexWhere((n) => n.id == id);
        if (i != -1) {
          _notifications[i] = updated;
          if (state is NotificationLoaded) {
            emit(NotificationLoaded(
              notifications: List.from(_notifications),
              unreadCount: _unreadCount,
            ));
          }
        }
      },
    );
  }

  Future<void> markAllAsRead() async {
    if (_notifications.isEmpty && state is NotificationLoaded) {
      _notifications = List.from((state as NotificationLoaded).notifications);
    }
    final now = DateTime.now();
    _notifications = _notifications.map((n) => n.copyWith(readAt: now)).toList();
    _unreadCount = 0;

    if (state is NotificationLoaded) {
      emit(NotificationLoaded(
        notifications: List.from(_notifications),
        unreadCount: 0,
      ));
    }

    final result = await repository.markAllAsRead();
    result.fold(
      (_) => loadNotifications(refresh: false),
      (_) {
        _unreadCount = 0;
        if (state is NotificationLoaded) {
          emit(NotificationLoaded(
            notifications: List.from(_notifications),
            unreadCount: 0,
          ));
        }
      },
    );
  }
}
