import 'package:cognitodraw/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home screen exposes session reset and metadata form', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Руководство пользователя'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Статус сессии'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Статус сессии'), findsOneWidget);
    expect(find.text('данные не подтверждены'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Новая сессия участника'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Новая сессия участника'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Введите свои данные'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Введите свои данные'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Загрузить данные вручную'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Загрузить данные вручную'), findsOneWidget);
    expect(find.text('Нет локальных GIF-файлов для загрузки.'), findsOneWidget);
  });
}
