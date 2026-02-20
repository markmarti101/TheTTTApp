import {
  collection,
  getDocs,
  query,
  where,
} from 'firebase/firestore';
import { db } from './firebase';

export interface TrainerOption {
  id: string;
  email: string;
  displayName?: string;
}

/**
 * Get trainers for a company.
 * Simplest: all users with role=freelance_trainer.
 * TODO: Filter by trainingCompanyId when trainer-company linking exists.
 */
export async function getTrainers(
  _trainingCompanyId: string
): Promise<TrainerOption[]> {
  const q = query(
    collection(db, 'users'),
    where('role', '==', 'freelance_trainer')
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({
    id: d.id,
    email: d.data().email ?? '',
    displayName: d.data().displayName,
  }));
}
