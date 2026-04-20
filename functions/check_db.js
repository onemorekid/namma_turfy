const admin = require('firebase-admin');

// Initialize with project ID
try {
    admin.initializeApp({
        projectId: 'turfy-7e791'
    });
} catch (e) {
    console.log('Initialization failed:', e);
    process.exit(1);
}

const db = admin.firestore();

async function check() {
    console.log('--- RECENT PENDING ORDERS ---');
    const poSnap = await db.collection('pending_orders')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
    
    poSnap.forEach(doc => {
        const d = doc.data();
        console.log(`ID: ${doc.id}, Status: ${d.status}, Player: ${d.playerId}, Created: ${d.createdAt?.toDate()}`);
    });

    console.log('\n--- RECENT BOOKINGS ---');
    const bSnap = await db.collection('bookings')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
    
    bSnap.forEach(doc => {
        const d = doc.data();
        console.log(`ID: ${doc.id}, Status: ${d.status}, Player: ${d.playerId}, Order: ${d.razorpayOrderId}, Payment: ${d.razorpayPaymentId}, Created: ${d.createdAt?.toDate()}`);
    });
}

check().catch(err => {
    console.error('Error querying Firestore:', err);
});
