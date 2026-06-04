import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/presentation/add_to_collection_locale_policy.dart';

CreatorMonoCollection _coll({String? contentLocale}) {
  return CreatorMonoCollection(
    id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    ownerId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    title: 'T',
    visibility: 'public',
    itemCount: 0,
    createdAt: '',
    updatedAt: '',
    contentLocale: contentLocale,
  );
}

void main() {
  test('detects mixed selected mono communities', () {
    expect(
      selectedMonosHaveMixedCommunities({
        'a': 'my',
        'b': 'en',
      }),
      isTrue,
    );
    expect(
      selectedMonosHaveMixedCommunities({'a': 'my', 'b': 'my'}),
      isFalse,
    );
  });

  test('my collection rejects en mono selection', () {
    final reason = collectionPickerDisabledReason(
      collection: _coll(contentLocale: 'my'),
      monoIdToContentLocale: {'m1': 'en'},
    );
    expect(reason, 'Different community');
  });

  test('legacy null collection accepts any mono', () {
    expect(
      collectionPickerDisabledReason(
        collection: _coll(),
        monoIdToContentLocale: {'m1': 'en'},
      ),
      isNull,
    );
  });
}
