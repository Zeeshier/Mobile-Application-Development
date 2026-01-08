import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_hub/main_screens/add_events_screens.dart';
import 'package:event_hub/main_screens/events_subscreens/event_details_screen.dart';
import 'package:event_hub/services/events_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({Key? key}) : super(key: key);

  Future<void> _confirmAndDelete(BuildContext context, String eventId, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete event'),
        content: const Text('Are you sure you want to delete this event?  This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EventService().deleteEvent(eventId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete event: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: BackButton(color: Theme.of(context).iconTheme.color),
      ),
      body: currentUser == null
          ? const Center(child: Text('Sign in to view your events. '))
          : StreamBuilder<QuerySnapshot>(
        // ✅ FIXED: Remove orderBy to avoid composite index requirement
        stream:  FirebaseFirestore.instance
            .collection('events')
            .where('organizerId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ Get docs and sort client-side
          final docs = snapshot.data?. docs ?? [];

          // ✅ Sort by date client-side (ascending order - earliest first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['date'] as Timestamp? ;
            final bDate = bData['date'] as Timestamp? ;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return aDate.compareTo(bDate); // ascending order
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No events created yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs. length,
            separatorBuilder:  (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ??  'Untitled Event';
              final location = data['location'] ?? 'No location';
              final imageUrl = data['imageUrl'] as String?;
              final attendees = data['attendees'] ??  0;

              final date = data['date'] as Timestamp?;
              final startTime = data['startTime'] as String? ;
              String dateLabel = 'TBA';
              if (date != null) {
                final dt = date.toDate();
                dateLabel = '${dt.day} ${_monthName(dt.month)}';
              }
              final startTimeLabel = startTime ??  'TBA';

              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? Image.network(imageUrl, width: 64, height: 64, fit:  BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.event, size: 40))
                        : Container(width: 64, height:  64, color: Theme.of(context).cardColor, child: const Icon(Icons.event, size: 36)),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$dateLabel • $startTimeLabel • $attendees going', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected:  (value) {
                      if (value == 'view') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: doc.id)),
                        );
                      } else if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddEventScreen(eventId: doc. id, eventData: data)),
                        );
                      } else if (value == 'delete') {
                        _confirmAndDelete(context, doc.id, ref);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'view', child: Text('View')),
                      const PopupMenuItem(value: 'edit', child:  Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: doc.id)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}