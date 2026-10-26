# 🤖 Mecha Protocol: Idle Survivor

Un *Bullet Heaven / Survivor* táctico pasivo diseñado para móviles (Android / iOS) con estética **Cyberpunk**.

---

## 🎯 Concepto y Diferenciador
* **Navegación Autónoma (Juega Solo):** El mecha cuenta con un algoritmo de navegación (*Steering Behaviors*) que evalúa en tiempo real las amenazas:
  * **Evasión de Peligro:** Fuerza de repulsión contra drones enemigos en base a su proximidad.
  * **Recolección de Chatarra (XP):** Fuerza de atracción hacia núcleos de energía caídos.
  * **Límites de Arena:** Evita quedar acorralado en las esquinas de la pantalla.
* **Armas Inteligentes:** Apuntado y disparo autónomo al objetivo más cercano.
* **Intervención del Jugador (Director):** Cuando el mecha recolecta suficiente XP y **sube de nivel**, el juego se pausa y muestra 3 cartas de hardware para instalar/mejorar.

---

## 📁 Estructura del Proyecto

* `scenes/`:
  * `main.tscn`: Escena principal del juego.
  * `mecha.tscn`: El robot táctico autónomo.
  * `enemy_drone.tscn`: Dron enemigo básico que persigue al jugador.
  * `bullet.tscn`: Proyectil láser neón del mecha.
  * `scrap.tscn`: Núcleo de chatarra/XP con sistema de imán.
  * `ui/hud.tscn`: Interfaz vertical (Barras de Vida y XP, Timer, Modal de Level Up).
* `scripts/`:
  * `mecha.gd`: IA de Steering Behaviors, combate y stats.
  * `enemy_drone.gd`: IA de persecución, daño y dropeo de loot.
  * `spawner.gd`: Generador procedural de oleadas perimetrales.
  * `hud.gd`: Control de interfaz y cartas de upgrades.
  * `main.gd`: Coordinador central de eventos y progresión.
  * `grid_background.gd`: Dibujado procedural de rejilla cyberpunk.

---

## 🚀 Cómo Ejecutar en Mac

1. Abre la aplicación **Godot**.
2. Haz clic en **Importar (Import)**.
3. Selecciona la carpeta `mecha_protocol` y confirma.
4. Presiona el botón de **Play (F5)** o el icono de reproducir arriba a la derecha.
