/**
 * Shared constants for the Training Triangle platform
 */

export const APP_NAME = 'The Training Triangle';

export const API_VERSION = 'v1';

export const COURSE_STATUS_LABELS = {
  draft: 'Draft',
  pending_trainer: 'Awaiting Trainer',
  confirmed: 'Confirmed',
  in_progress: 'In Progress',
  completed: 'Completed',
  cancelled: 'Cancelled',
} as const;

export const DOCUMENT_TYPES = [
  'booking_form',
  'venue_details',
  'pre_course_pack',
  'certificate',
  'insurance',
  'dbs',
  'qualification',
  'contract',
] as const;

export const CALENDAR_VIEWS = ['month', 'week', 'day', 'user'] as const;
