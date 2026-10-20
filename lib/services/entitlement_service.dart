import 'package:supabase_flutter/supabase_flutter.dart';

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.creditsRemaining,
    required this.trialStarted,
    required this.trialActive,
    required this.lifetimeUnlocked,
    this.trialExpiresAt,
  });

  final int creditsRemaining;
  final bool trialStarted;
  final bool trialActive;
  final bool lifetimeUnlocked;
  final DateTime? trialExpiresAt;

  factory EntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    return EntitlementSnapshot(
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 20,
      trialStarted: json['trial_started'] == true,
      trialActive: json['trial_active'] == true,
      lifetimeUnlocked: json['lifetime_unlocked'] == true,
      trialExpiresAt: json['trial_expires_at'] == null
          ? null
          : DateTime.tryParse(json['trial_expires_at'].toString())?.toLocal(),
    );
  }

  bool get canUsePremium => lifetimeUnlocked || trialActive;
}

class EntitlementService {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<EntitlementSnapshot> refresh() async {
    final result = await _client.rpc('get_my_entitlement');
    return EntitlementSnapshot.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Deducts credits transactionally on the server. Use a fresh request UUID
  /// for each user-initiated generation; retry with the same UUID on network retry.
  Future<EntitlementSnapshot> consumeCredits({required int count, required String requestId}) async {
    final result = await _client.rpc('consume_generation_credits', params: {
      'p_count': count,
      'p_request_id': requestId,
    });
    return EntitlementSnapshot.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<bool> canOpenPremiumFeature() async {
    final result = await _client.rpc('check_premium_access');
    return (result as Map)['allowed'] == true;
  }
}
