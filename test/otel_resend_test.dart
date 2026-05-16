// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_resend/otel_resend.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_resend-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('send records CLIENT span', () async {
    await tracedResendSend<String>(
      from: 'noreply@dartastic.io',
      to: ['a@x.com', 'b@x.com'],
      subject: 'Welcome',
      attachmentCount: 1,
      invoke: () async => const ResendSendResult(
        value: 'ok',
        emailId: 're_123',
      ),
    );
    final a = attrsOf(spans.findSpanByName('resend send')!);
    expect(a['messaging.system'], 'resend');
    expect(a['messaging.destination.name'], 'email');
    expect(a['email.from'], 'noreply@dartastic.io');
    expect(a['email.to.count'], 2);
    expect(a['email.subject'], 'Welcome');
    expect(a['email.attachments.count'], 1);
    expect(a['messaging.message.id'], 're_123');
    expect(a['resend.email.id'], 're_123');
  });

  test('suppression skips spans', () async {
    await runWithoutResendInstrumentationAsync(() async {
      await tracedResendSend<String>(
        from: 'a@x',
        to: ['b@x'],
        invoke: () async => const ResendSendResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('resend '), isEmpty);
  });
}
