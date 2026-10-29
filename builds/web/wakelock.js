// Screen Wake Lock API para evitar que la pantalla se bloquee o atenúe en navegadores móviles (iOS Safari, Chrome, etc.)
(function() {
    let wakeLock = null;

    async function acquireWakeLock() {
        try {
            if ('wakeLock' in navigator && (!wakeLock || wakeLock.released)) {
                wakeLock = await navigator.wakeLock.request('screen');
                console.log('[WakeLock] Pantalla activa fijada.');
                wakeLock.addEventListener('release', () => {
                    console.log('[WakeLock] Wake Lock liberado.');
                });
            }
        } catch (err) {
            // Wake Lock puede no estar permitido hasta que haya interacción
        }
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        acquireWakeLock();
    } else {
        window.addEventListener('DOMContentLoaded', acquireWakeLock);
    }

    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') {
            acquireWakeLock();
        }
    });

    ['touchstart', 'touchend', 'pointerdown', 'mousedown', 'keydown'].forEach(evt => {
        window.addEventListener(evt, () => {
            acquireWakeLock();
        }, { passive: true });
    });
})();
