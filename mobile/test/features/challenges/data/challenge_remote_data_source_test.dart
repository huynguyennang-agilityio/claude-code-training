import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/features/challenges/data/datasources/challenge_remote_data_source.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';

import '../../../helpers/fake_http_adapter.dart';

const _card = {
  'id': 7,
  'title': 'Hoan Kiem 50K Steps',
  'type': 'run',
  'metric': 'steps',
  'target_value': 50000,
  'cover_image_url': null,
  'city': null,
  'landmark': null,
  'status': 'published',
  'starts_at': '2026-11-01T00:00:00Z',
  'ends_at': '2026-11-30T23:59:59Z',
  'participant_count': 3,
  'enrollment': null,
};

DioChallengeRemoteDataSource _source(
  FakeHttpHandler handler, {
  Duration timeout = const Duration(seconds: 15),
}) => DioChallengeRemoteDataSource(
  createDio(baseUrl: 'http://api.test/', adapter: FakeHttpAdapter(handler)),
  timeout: timeout,
);

Future<ChallengeFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ChallengeFailure catch (failure) {
    return failure;
  }
  fail('Expected a ChallengeFailure');
}

ResponseBody _error(String code, int status, [String message = 'ignored']) =>
    jsonBody({
      'error': {'code': code, 'message': message, 'fields': []},
    }, status);

void main() {
  group('list', () {
    test('sends the filters and parses the page', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({
          'items': [_card],
          'next_cursor': 'OQ',
        }, 200);
      });

      final page = await source.list(
        type: ChallengeType.swim,
        query: '  lake ',
        cursor: 'abc',
        limit: 5,
      );

      expect(sent.method, 'GET');
      expect(sent.path, 'challenges');
      expect(sent.queryParameters, {
        'type': 'swim',
        'q': 'lake',
        'cursor': 'abc',
        'limit': 5,
      });
      expect(page.items.single.title, 'Hoan Kiem 50K Steps');
      expect(page.nextCursor, 'OQ');
    });

    test('leaves out a blank search and no cursor', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({'items': [], 'next_cursor': null}, 200);
      });

      await source.list(query: '   ');

      expect(sent.queryParameters, {'limit': 20});
    });
  });

  group('get', () {
    test('asks for the challenge by id', () async {
      late RequestOptions sent;
      final source = _source((request) async {
        sent = request;
        return jsonBody({
          ..._card,
          'description_md': 'About',
          'terms_md': '',
          'medals': [],
          'blocked_by': null,
        }, 200);
      });

      final challenge = await source.get(7);

      expect(sent.path, 'challenges/7');
      expect(challenge.descriptionMd, 'About');
    });
  });

  group('errors', () {
    test('a documented code becomes its failure', () async {
      final source = _source((_) async => _error('challenge_not_found', 404));

      final failure = await _failureOf(source.get(7));

      expect(failure.code, ChallengeFailureCode.challengeNotFound);
      expect(failure.message, 'This challenge is not available.');
    });

    test('an unknown code is unknown', () async {
      final source = _source((_) async => _error('something_new', 409));

      expect(
        (await _failureOf(source.get(7))).code,
        ChallengeFailureCode.unknown,
      );
    });

    test('a body that is not an error response is unknown', () async {
      final source = _source((_) async => textBody('<html>oops</html>', 502));

      expect(
        (await _failureOf(source.get(7))).code,
        ChallengeFailureCode.unknown,
      );
    });

    test('a success body of the wrong shape is unknown', () async {
      final source = _source((_) async => jsonBody({'items': 'nope'}, 200));

      expect(
        (await _failureOf(source.list())).code,
        ChallengeFailureCode.unknown,
      );
    });

    test('an empty success body is unknown', () async {
      final source = _source((_) async => textBody('', 200));

      expect(
        (await _failureOf(source.get(7))).code,
        ChallengeFailureCode.unknown,
      );
    });

    test('the overlap message of the server is kept', () async {
      final source = _source(
        (_) async =>
            _error('overlapping_challenge', 409, 'You are already in “X”.'),
      );

      final failure = await _failureOf(source.get(7));

      expect(failure.code, ChallengeFailureCode.overlappingChallenge);
      expect(failure.message, 'You are already in “X”.');
    });

    test('a transport error is a network failure', () async {
      final source = _source(
        (request) async => throw DioException(requestOptions: request),
      );

      expect(
        (await _failureOf(source.get(7))).code,
        ChallengeFailureCode.network,
      );
    });

    test('a slow server is a network failure', () async {
      final source = _source(
        (_) => Completer<ResponseBody>().future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        (await _failureOf(source.get(7))).code,
        ChallengeFailureCode.network,
      );
    });
  });
}
