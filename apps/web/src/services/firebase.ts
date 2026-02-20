import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyAVISBFPZ7vcIJrV1qLvUoqNFPIL4id87U',
  authDomain: 'training-triangle-app.firebaseapp.com',
  projectId: 'training-triangle-app',
  storageBucket: 'training-triangle-app.firebasestorage.app',
  messagingSenderId: '861837788735',
  appId: '1:861837788735:web:7b858039d08984fc4e1a8a',
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
