/**
 * User roles for the Training Triangle platform
 */
export type UserRole = 'training_company' | 'freelance_trainer' | 'client';

export const USER_ROLES: Record<UserRole, string> = {
  training_company: 'Training Company',
  freelance_trainer: 'Freelance Trainer',
  client: 'Client',
} as const;

/**
 * Training Company admin permission levels
 */
export type AdminPermission =
  | 'full_access'
  | 'bookings'
  | 'forms'
  | 'reports'
  | 'delegates'
  | 'read_only';
