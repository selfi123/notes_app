import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/contacts/screens/contacts_list_screen.dart';
import '../../features/contacts/screens/contact_detail_screen.dart';
import '../../features/notes/screens/add_note_screen.dart';
import '../../features/notes/screens/notes_list_screen.dart';
import '../../features/premium/screens/premium_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/shell/screens/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/contacts',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Contacts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                name: 'contacts',
                builder: (context, state) => const ContactsListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'contact-detail',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      final name = state.uri.queryParameters['name'] ?? '';
                      return ContactDetailScreen(contactId: id, contactName: name);
                    },
                    routes: [
                      GoRoute(
                        path: 'add-note',
                        name: 'add-note',
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name = state.uri.queryParameters['name'] ?? '';
                          return AddNoteScreen(contactId: id, contactName: name);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          // Branch 1: Notes
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                name: 'notes',
                builder: (context, state) => const NotesListScreen(),
              ),
            ],
          ),

          // Branch 2: Premium
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/premium',
                name: 'premium',
                builder: (context, state) => const PremiumScreen(),
              ),
            ],
          ),

          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
