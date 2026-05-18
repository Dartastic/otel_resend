// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_resend_suppression.dart';

const _tracerName = 'dartastic_otel_libs_resend';
const _systemValue = 'resend';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedResendSend` callback.
class ResendSendResult<T> {
  const ResendSendResult({required this.value, this.emailId});
  final T value;
  final String? emailId;
}

/// Wraps a Resend `emails.send` in a CLIENT span using OTel
/// messaging.* semconv with system=resend.
Future<T> tracedResendSend<T>({
  required String from,
  required List<String> to,
  required Future<ResendSendResult<T>> Function() invoke,
  String? subject,
  int? attachmentCount,
}) async {
  if (resendInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'messaging.system': _systemValue,
    'messaging.operation': 'publish',
    'messaging.destination.name': 'email',
    'email.from': from,
    'email.to.count': to.length,
    if (subject != null) 'email.subject': subject,
  };
  if (attachmentCount != null) {
    m['email.attachments.count'] = attachmentCount;
  }

  final span = _tracer().startSpan(
    'resend send',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.emailId != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeString('messaging.message.id', r.emailId!),
        OTel.attributeString('resend.email.id', r.emailId!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
