/* Farvixo FCM service worker — farvixo-production-2026 (public web config) */
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCW6-ik0yBIkrHH2ScoZFEFD3u5qhUS5SU',
  authDomain: 'farvixo-production-2026.firebaseapp.com',
  projectId: 'farvixo-production-2026',
  storageBucket: 'farvixo-production-2026.firebasestorage.app',
  messagingSenderId: '282376161241',
  appId: '1:282376161241:web:d0bca9dcc89c299e1f7bc8',
  measurementId: 'G-VTGV5YE47C',
});

firebase.messaging().onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Farvixo';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/favicon.svg',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
