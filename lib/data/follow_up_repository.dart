import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart' as sb;

class FollowUpCall {
  final String id;
  final String customerId;
  final String? billId;
  final String callerId;
  final String callerChannel;
  final String callOutcome;
  final String? commitmentAction;
  final String? promisedDate;
  final String? notes;
  final String calledAt;
  final String? nextFollowUpDate;

  const FollowUpCall({
    required this.id,
    required this.customerId,
    this.billId,
    required this.callerId,
    required this.callerChannel,
    required this.callOutcome,
    this.commitmentAction,
    this.promisedDate,
    this.notes,
    required this.calledAt,
    this.nextFollowUpDate,
  });

  factory FollowUpCall.fromJson(Map<String, dynamic> j) => FollowUpCall(
    id: j['id'] as String,
    customerId: j['customer_id'] as String,
    billId: j['bill_id'] as String?,
    callerId: j['caller_id'] as String,
    callerChannel: j['caller_channel'] as String,
    callOutcome: j['call_outcome'] as String,
    commitmentAction: j['commitment_action'] as String?,
    promisedDate: j['promised_date'] as String?,
    notes: j['notes'] as String?,
    calledAt: j['called_at'] as String,
    nextFollowUpDate: j['next_follow_up_date'] as String?,
  );
}

class CommitmentEvent {
  final String id;
  final String customerId;
  final String? billId;
  final String eventType;
  final String summary;
  final String? promisedDate;
  final String createdAt;

  const CommitmentEvent({
    required this.id,
    required this.customerId,
    this.billId,
    required this.eventType,
    required this.summary,
    this.promisedDate,
    required this.createdAt,
  });

  factory CommitmentEvent.fromJson(Map<String, dynamic> j) => CommitmentEvent(
    id: j['id'] as String,
    customerId: j['customer_id'] as String,
    billId: j['bill_id'] as String?,
    eventType: j['event_type'] as String,
    summary: j['summary'] as String,
    promisedDate: j['promised_date'] as String?,
    createdAt: j['created_at'] as String,
  );
}

class BillCallStats {
  final int total;
  final int office;
  final int agent;

  const BillCallStats({required this.total, required this.office, required this.agent});
}

class FollowUpRepository {
  final SupabaseClient supabase;

  FollowUpRepository({SupabaseClient? client})
    : supabase = client ?? sb.supabase;

  Future<void> recordCall({
    required String customerId,
    required String? billId,
    required String callerId,
    required String callerChannel,
    required String callOutcome,
    String? commitmentAction,
    String? promisedDate,
    String? notes,
    String? nextFollowUpDate,
  }) async {
    await supabase.from('follow_up_calls').insert({
      'customer_id': customerId,
      'bill_id': billId,
      'caller_id': callerId,
      'caller_channel': callerChannel,
      'call_outcome': callOutcome,
      'commitment_action': commitmentAction,
      'promised_date': promisedDate,
      'notes': notes,
      'next_follow_up_date': nextFollowUpDate,
    });
  }

  Future<List<FollowUpCall>> fetchCallsForBill(String billId) async {
    final rows = await supabase
        .from('follow_up_calls')
        .select()
        .eq('bill_id', billId)
        .order('called_at', ascending: false);
    return (rows as List)
        .map((j) => FollowUpCall.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<BillCallStats> fetchStatsForBill(String billId) async {
    final rows = await supabase
        .from('follow_up_calls')
        .select('caller_channel')
        .eq('bill_id', billId);
    var office = 0;
    var agent = 0;
    for (final row in rows as List) {
      final channel = (row as Map<String, dynamic>)['caller_channel'] as String?;
      if (channel == 'office') office++;
      if (channel == 'recovery_agent') agent++;
    }
    return BillCallStats(total: rows.length, office: office, agent: agent);
  }

  Future<List<CommitmentEvent>> fetchCommitmentEvents(String customerId) async {
    final rows = await supabase
        .from('customer_commitment_events')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(40);
    return (rows as List)
        .map((j) => CommitmentEvent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerDeviceToken({
    required String staffId,
    required String token,
    required String platform,
  }) async {
    await supabase.from('staff_device_tokens').upsert({
      'staff_id': staffId,
      'fcm_token': token,
      'platform': platform,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'staff_id,fcm_token');
  }
}