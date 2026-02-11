/**
 * Core entity types for the Training Triangle platform
 */

import type { UserRole } from './roles.js';

// --- User & Auth ---
export interface User {
  id: string;
  email: string;
  role: UserRole;
  displayName?: string;
  avatarUrl?: string;
  createdAt: string;
  updatedAt: string;
}

// --- Training Company ---
export interface TrainingCompany {
  id: string;
  name: string;
  admins: string[]; // User IDs
  permissions?: Record<string, string[]>; // userId -> AdminPermission[]
  settings?: CompanySettings;
  createdAt: string;
  updatedAt: string;
}

export interface CompanySettings {
  timezone?: string;
  currency?: string;
  defaultContractTemplate?: string;
  lmsConnectionSettings?: Record<string, LMSSettings>;
}

export interface LMSSettings {
  provider: 'moodle' | 'totara' | 'learnupon' | 'custom';
  apiUrl?: string;
  apiKey?: string;
  syncEnabled: boolean;
}

// --- Freelance Trainer ---
export interface FreelanceTrainer extends User {
  qualifications: Qualification[];
  insurance?: DocumentRecord;
  dbsCheck?: DocumentRecord;
  cpdLogs?: CPDLog[];
  bankingDetails?: BankingDetails;
  availability?: AvailabilitySlot[];
  ratings?: number;
  acceptedJobs: string[]; // Course IDs
}

export interface Qualification {
  id: string;
  name: string;
  issuingBody?: string;
  expiryDate?: string;
  documentUrl?: string;
  status: 'valid' | 'expired' | 'pending';
}

export interface DocumentRecord {
  type: string;
  documentUrl?: string;
  expiryDate?: string;
  status: 'valid' | 'expired' | 'pending';
  lastVerified?: string;
}

export interface CPDLog {
  id: string;
  date: string;
  activity: string;
  hours: number;
  documentUrl?: string;
}

export interface BankingDetails {
  accountName?: string;
  sortCode?: string;
  accountNumber?: string;
  bankName?: string;
}

export interface AvailabilitySlot {
  start: string;
  end: string;
  recurring?: boolean;
}

// --- Client ---
export interface Client extends User {
  companyId: string;
  organisationName?: string;
  customPricing?: Record<string, number>;
  delegates: Delegate[];
  venueIds: string[];
  poNumbers?: string[];
  lmsExportFormat?: 'csv' | 'xml';
}

export interface Delegate {
  id: string;
  name: string;
  email?: string;
  accessibilityNotes?: string;
  dietaryRequirements?: string;
  history?: string[]; // Course IDs
}

// --- Course & Scheduling ---
export interface Course {
  id: string;
  courseNumber: string; // Unique generated number
  poNumber?: string;
  title: string;
  topic: string;
  trainingCompanyId: string;
  trainerId?: string;
  clientId: string;
  venueId?: string;
  startDate: string;
  endDate: string;
  status: CourseStatus;
  delegateIds?: string[];
  kitAllocations?: KitAllocation[];
  documents?: CourseDocument[];
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export type CourseStatus =
  | 'draft'
  | 'pending_trainer'
  | 'confirmed'
  | 'in_progress'
  | 'completed'
  | 'cancelled';

export interface KitAllocation {
  itemId: string;
  quantity: number;
}

export interface CourseDocument {
  id: string;
  type: string;
  url: string;
  courseNumber: string;
  uploadedAt: string;
  uploadedBy: string;
}

// --- Venue ---
export interface Venue {
  id: string;
  name: string;
  address: string;
  clientId?: string;
  trainingCompanyId: string;
  capacity?: number;
  detailsDocumentUrl?: string;
  createdAt: string;
  updatedAt: string;
}

// --- Resource & Inventory ---
export interface Resource {
  id: string;
  name: string;
  type: 'book' | 'material' | 'kit';
  quantity: number;
  threshold?: number; // Alert when below
  trainingCompanyId: string;
  allocated?: Record<string, number>; // courseId -> quantity
}
