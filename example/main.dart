// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_resend/otel_resend.dart';

/// Traces Resend calls with OpenTelemetry.
///
/// `otel_resend` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Resend call in
/// [tracedResendSend]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'resend-example');

  // Wraps a Resend emails.send in a CLIENT span using OTel messaging.* semconv with system=resend.
  final resendSendId = await tracedResendSend<String>(
    from: 'example',
    to: ['example'],
    subject: 'example',
    attachmentCount: 3,
    invoke: () async {
      // Make the Resend call here, then report what it returned.
      const id = 'resend_8f3a2c';
      return const ResendSendResult(value: id, emailId: 'email_8f3a2c');
    },
  );
  OTelLog.info('tracedResendSend emails.send returned $resendSendId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutResendInstrumentationAsync.
  await runWithoutResendInstrumentationAsync(
    () => tracedResendSend<String>(
      from: 'example',
      to: ['example'],
      subject: 'example',
      attachmentCount: 3,
      invoke: () async {
        const id = 'resend_8f3a2c';
        return const ResendSendResult(value: id, emailId: 'email_8f3a2c');
      },
    ),
  );

  await OTel.shutdown();
}
