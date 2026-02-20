import {
  collection,
  doc,
  getDoc,
  getDocs,
  addDoc,
  updateDoc,
  query,
  where,
  orderBy,
} from 'firebase/firestore';
import { db } from './firebase';
import type { CourseRequest } from '@training-triangle/shared';

const REQUESTS = 'course_requests';
const COURSES = 'courses';

export async function getRequestsByCompany(
  trainingCompanyId: string
): Promise<(CourseRequest & { id: string })[]> {
  const q = query(
    collection(db, REQUESTS),
    where('trainingCompanyId', '==', trainingCompanyId),
    orderBy('createdAt', 'desc')
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() } as CourseRequest & { id: string }));
}

export async function getRequest(
  id: string
): Promise<(CourseRequest & { id: string }) | null> {
  const d = await getDoc(doc(db, REQUESTS, id));
  if (!d.exists()) return null;
  return { id: d.id, ...d.data() } as CourseRequest & { id: string };
}

export async function markRequestReviewed(id: string): Promise<void> {
  const req = await getRequest(id);
  if (req?.status === 'pending') {
    await updateDoc(doc(db, REQUESTS, id), {
      status: 'reviewed',
      updatedAt: new Date().toISOString(),
    });
  }
}

export async function declineRequest(
  id: string,
  reason: string
): Promise<void> {
  await updateDoc(doc(db, REQUESTS, id), {
    status: 'declined',
    declineReason: reason,
    updatedAt: new Date().toISOString(),
  });
}

export async function approveRequest(
  requestId: string,
  trainerId: string,
  scheduledAt: string
): Promise<string> {
  const req = await getRequest(requestId);
  if (!req) throw new Error('Request not found');
  if (req.status !== 'pending' && req.status !== 'reviewed') {
    throw new Error('Request already processed');
  }

  const courseNumber = `TT-${new Date().getFullYear()}-${Date.now().toString(36).toUpperCase().slice(-6)}`;
  const scheduledDate = new Date(scheduledAt);
  const endDate = new Date(scheduledDate);
  endDate.setHours(17, 0, 0, 0);

  const courseRef = await addDoc(collection(db, COURSES), {
    courseNumber,
    title: req.title,
    topic: req.topic ?? '',
    trainingCompanyId: req.trainingCompanyId,
    clientId: req.clientId,
    trainerId,
    startDate: scheduledDate.toISOString(),
    endDate: endDate.toISOString(),
    status: 'pending_trainer',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });

  await updateDoc(doc(db, REQUESTS, requestId), {
    status: 'approved',
    updatedAt: new Date().toISOString(),
  });

  return courseRef.id;
}
