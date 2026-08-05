import 'package:djassa/core/services/supabase_service.dart';
import 'package:djassa/presentation/providers/auth_provider.dart';
import 'package:djassa/presentation/screens/delivery/model/courier_assignment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stream qui écoute les nouvelles attributions pour le livreur connecté
final activeAssignmentStreamProvider = StreamProvider<CourierAssignment?>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return Stream.value(null);

  return SupabaseService.client
      .from('order_assignments')
      .stream(primaryKey: ['id'])
      .map((data) {
        // Filtrage manuel côté client pour éviter les erreurs de syntaxe Supabase
        final filtered = data.where((row) {
          return row['courier_id'] == user.id && 
                 row['status'] == 'pending';
        }).toList();

        if (filtered.isEmpty) return null;
        return CourierAssignment.fromJson(filtered.first);
      });
});

class AssignmentService {
  Future<bool> acceptAssignment(String assignmentId, String orderId) async {
    try {
      final response = await SupabaseService.client.rpc('accept_courier_offer', params: {
        'p_assignment_id': assignmentId,
        'p_order_id': orderId,
        'p_courier_id': SupabaseService.client.auth.currentUser!.id
      });
      
      if (response.error != null) throw Exception(response.error!.message);
      return true;
    } catch (e) {
      print("Erreur acceptation: $e");
      return false;
    }
  }

  Future<void> refuseAssignment(String assignmentId) async {
    await SupabaseService.client
        .from('order_assignments')
        .update({'status': 'refused', 'responded_at': DateTime.now().toIso8601String()})
        .eq('id', assignmentId);
  }
}

final assignmentServiceProvider = Provider((ref) => AssignmentService());