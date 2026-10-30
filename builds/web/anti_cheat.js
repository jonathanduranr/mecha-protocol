// ===============================================================
// MECHA PROTOCOL - CENTINELA WEB ANTI-CHEAT & RUNTIME SHIELD
// ===============================================================
(() => {
    'use strict';

    // 1. Detección y bloqueo del timer de truco conocido `window._hpLoop`
    let _hpLoop = undefined;
    try {
        Object.defineProperty(window, '_hpLoop', {
            get() { return _hpLoop; },
            set(val) {
                console.warn("%c🛡️ [CENTINELA] Intento de inyección de temporizador '_hpLoop' neutralizado.", "color: #ff3333; font-weight: bold; font-size: 13px;");
                if (val) clearInterval(val);
                _hpLoop = null;
            },
            configurable: false
        });
    } catch (e) {}

    // 2. Interceptar window.Engine para proteger Module / rtenv (HEAPF64, HEAP32, etc.)
    let _Engine = undefined;
    const rtenvMap = new WeakMap();

    function createProtectedModuleProxy(realModule) {
        if (!realModule || typeof realModule !== 'object') return realModule;
        return new Proxy(realModule, {
            get(target, prop, receiver) {
                const propStr = String(prop);
                // Bloquear vistas directas de memoria lineal WASM ejecutadas desde scripts externos
                if (propStr.startsWith('HEAP') || propStr === 'buffer') {
                    console.warn(`%c🛡️ [CENTINELA] Acceso restringido a '${propStr}'. Acceso a memoria bloqueado.`, "color: #ff3333; font-weight: bold; font-size: 13px;");
                    return undefined;
                }
                const val = Reflect.get(target, prop, receiver);
                return typeof val === 'function' ? val.bind(target) : val;
            }
        });
    }

    try {
        Object.defineProperty(window, 'Engine', {
            get() {
                return _Engine;
            },
            set(EngineClass) {
                _Engine = EngineClass;
                if (EngineClass && EngineClass.prototype) {
                    Object.defineProperty(EngineClass.prototype, 'rtenv', {
                        get() {
                            const real = rtenvMap.get(this);
                            if (!real) return undefined;
                            return createProtectedModuleProxy(real);
                        },
                        set(val) {
                            rtenvMap.set(this, val);
                        },
                        configurable: true
                    });
                }
            },
            configurable: true
        });
    } catch (e) {}
})();
