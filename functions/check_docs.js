const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'training-triangle-app' });
const db = admin.firestore();

db.collection('documents').get().then(snap => {
  if (snap.empty) {
    console.log('No documents found in collection');
  } else {
    snap.forEach(d => {
      const data = d.data();
      console.log(JSON.stringify({
        id: d.id,
        fileName: data.fileName,
        courseId: data.courseId,
        courseNumber: data.courseNumber,
        clientId: data.clientId || '(none)',
        uploadedBy: data.uploadedBy,
        uploaderRole: data.uploaderRole,
        createdAt: data.createdAt
      }));
    });
  }
  process.exit(0);
}).catch(e => { console.error('Error:', e.message); process.exit(1); });
