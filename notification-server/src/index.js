const admin = require('firebase-admin');
   const express = require('express');
   const cors = require('cors');

   // Initialize Express app
   const app = express();
   app.use(cors());
   app.use(express.json());

   // Initialize Firebase Admin SDK
   const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
   admin.initializeApp({
     credential: admin.credential.cert(serviceAccount),
     databaseURL: 'https://smart-fireguard-default-rtdb.firebaseio.com/'
    });


   const db = admin.database();
   const messaging = admin.messaging();

   // Listen for new entries in user_logs
   db.ref('user_logs').on('child_added', async (snapshot) => {
     const userId = snapshot.key;
     const log = snapshot.val();
     const latestLogKey = Object.keys(log).pop();
     const latestLog = log[latestLogKey];

     console.log(`New log for user ${userId}:`, latestLog);

     // Get the user's FCM token
     const tokenSnapshot = await db.ref(`device_ids/${userId}`).once('value');
     const fcmToken = tokenSnapshot.val();

     if (!fcmToken) {
       console.log(`No FCM token found for user ${userId}`);
       return;
     }

     // Prepare notification payload
     const notifType = latestLog.type || 'default';
     const payload = {
       notification: {
         title: notifType,
         body: getNotificationBody(notifType, latestLog),
       },
       data: {
         userId: userId,
         payload: `type:${notifType}`,
         smoke: latestLog.smoke || '-',
         temperature: latestLog.temperature || '-',
         flame: latestLog.flame === 'YES' ? 'true' : 'false'
       },
       token: fcmToken
     };

     // Send notification
     try {
       await messaging.send(payload);
       console.log(`Notification sent to user ${userId}:`, payload);
     } catch (error) {
       console.error(`Error sending notification to user ${userId}:`, error);
     }
   });

   // Helper function to generate notification body
   function getNotificationBody(notifType, log) {
     switch (notifType) {
       case 'FLAME DETECTED':
         return 'Check for open flames or fire sources immediately.';
       case 'SMOKE DETECTED':
         return 'Smoke levels are high, please investigate.';
       case 'EMERGENCY':
         return 'Immediate action required: high smoke and temperature detected.';
       default:
         return 'A new event has occurred.';
     }
   }

   // Health check endpoint for Render
   app.get('/health', (req, res) => {
     res.status(200).send('OK');
   });

   // Start the server
   const port = process.env.PORT || 3000;
   app.listen(port, () => {
     console.log(`Server running on port ${port}`);
   });