import 'package:equatable/equatable.dart';
import '../../data/models/menu_item.dart';

abstract class MenuState extends Equatable {
  const MenuState();
  @override List<Object?> get props => [];
}

class MenuInitial extends MenuState { const MenuInitial(); }
class MenuLoading extends MenuState { const MenuLoading(); }
class MenuEmpty   extends MenuState { const MenuEmpty(); }

class MenuLoaded extends MenuState {
  final List<MenuItem> items;
  const MenuLoaded(this.items);
  @override List<Object?> get props => [items];
}

class MenuError extends MenuState {
  final String message;
  const MenuError(this.message);
  @override List<Object?> get props => [message];
}

class MenuSaving extends MenuState {
  final List<MenuItem> items;
  const MenuSaving(this.items);
  @override List<Object?> get props => [items];
}

