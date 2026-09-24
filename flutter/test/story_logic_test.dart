import 'package:dracondex/core/narrator/story_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, StoryVar> vars() => {
        'cobj_1': StoryVar('cobj_1', 'Gold', 'number', '10'),
        'cobj_2': StoryVar('cobj_2', 'Met king', 'bool', 'false'),
        'cobj_3': StoryVar('cobj_3', 'Title', 'text', 'Sir'),
      };

  test('conditions: every entry must hold; an unknown variable fails', () {
    final v = vars();
    expect(StoryLogic.holds([{'key': 'cobj_1', 'op': '>=', 'value': '10'}], v), isTrue);
    expect(StoryLogic.holds([{'key': 'cobj_1', 'op': '>', 'value': '10'}], v), isFalse);
    expect(StoryLogic.holds([{'key': 'cobj_2', 'op': '==', 'value': 'false'}, {'key': 'cobj_3', 'op': '==', 'value': 'Sir'}], v), isTrue);
    expect(StoryLogic.holds([{'key': 'cobj_9', 'op': '==', 'value': '1'}], v), isFalse);
    expect(StoryLogic.holds([], v), isTrue);
  });

  test('set-ops apply in order, by type', () {
    final v = vars();
    StoryLogic.apply(
      StoryLogic.parse('[{"key":"cobj_1","op":"-=","value":"3"},{"key":"cobj_1","op":"+=","value":"0.5"},'
          '{"key":"cobj_2","op":"toggle","value":""},{"key":"cobj_3","op":"+=","value":" Bob"}]'),
      v,
    );
    expect(v['cobj_1']!.value, 7.5);
    expect(v['cobj_2']!.value, true);
    expect(v['cobj_3']!.value, 'Sir Bob');
    StoryLogic.apply([{'key': 'cobj_1', 'op': '=', 'value': '2'}], v);
    expect(v['cobj_1']!.value, 2);
  });

  test('bad JSON reads as no logic', () {
    expect(StoryLogic.parse('{nope'), isEmpty);
    expect(StoryLogic.parse(null), isEmpty);
  });
}
