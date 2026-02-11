/**
 * Database schema definitions
 * Use with Firestore collections or PostgreSQL migrations
 *
 * Collections/Tables:
 * - users
 * - training_companies
 * - freelance_trainers
 * - clients
 * - courses
 * - venues
 * - resources
 * - documents
 */

export const COLLECTIONS = {
  USERS: 'users',
  TRAINING_COMPANIES: 'training_companies',
  FREELANCE_TRAINERS: 'freelance_trainers',
  CLIENTS: 'clients',
  COURSES: 'courses',
  VENUES: 'venues',
  RESOURCES: 'resources',
  DOCUMENTS: 'documents',
  AUDIT_LOG: 'audit_log',
} as const;
