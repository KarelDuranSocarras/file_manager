# Documento de Acuerdo — App de respaldo a Google Drive (v1)

> Confirmado por el product owner el 2026-11-16. Cualquier cambio a este documento
> requiere acuerdo explícito antes de implementarse.

## 1. Producto

App de escritorio **Windows y Linux** que respalda **automáticamente** una carpeta
local del usuario en **Google Drive**, y permite **restaurar todo** en un equipo
nuevo. Vive en segundo plano como app nativa (bandeja, autostart, notificaciones).

## 2. Alcance funcional

1. **Solo sube** (unidireccional, local → nube). Nada baja salvo restauración manual.
2. **Última versión gana**: si el archivo existe en Drive, se reemplaza sin copia
   previa a papelera; sin historial de versiones.
3. **Un solo equipo** por destino; **una sola carpeta**, siempre en **disco interno**.
4. **Borrado local → papelera en la nube**: recuperable **15 días**, luego
   eliminación definitiva. Lo modificado no tiene papelera (se pisa directo).
5. **Restauración desde la propia app** en un equipo nuevo.

## 3. Modelo de acceso (sin servidor)

6. **Una sola cuenta de Google para todos los clientes**, archivos **sin separar**
   en una misma carpeta (la cuota se reparte entre todos).
7. **Sin servidor propio y sin pantallas de sesión**: las credenciales de la cuenta
   se **incrustan al compilar**, leídas de un `.env` en la máquina de compilación.
8. **Riesgo asumido conscientemente**: alguien técnico podría extraer las
   credenciales y acceder a toda la cuenta (todos los archivos de todos los clientes).

## 4. Experiencia de usuario

9. **Primer arranque**: solo elegir carpeta; resto por defecto.
10. **Ventana principal**: estado general (al día / subiendo / error), carpeta
    respaldada, **lista de actividad** (subidas, errores, pausas) y acciones.
11. **Bandeja**: pausar/reanudar, sincronizar ahora, abrir carpeta local. La **X
    minimiza a la bandeja**; salir solo desde el menú de la bandeja.
12. **Notificaciones minimalistas**: solo errores y eventos críticos.
13. Interfaz **solo en español**.

## 5. Sincronización

14. **Disparo configurable por el usuario** (en vivo o por intervalos); **por
    defecto: intervalos**.
15. Un archivo en edición espera **1–3 min sin cambios** antes de subirse.
16. **Exclusiones**: temporales/ocultos/sistema por defecto **+ reglas propias del
    usuario** en ajustes.
17. **Límite 100 MB por archivo**: lo mayor se salta y se avisa.

## 6. Casos límite

18. **Archivo bloqueado**: reintentos limitados → saltar, anotar y avisar;
    reintenta en la siguiente pasada.
19. **Sin conexión**: cola persistente en disco; sube solo al volver la conexión;
    **aviso único tras 1 hora** sin poder respaldar.
20. **Cuota**: avisos al llegar al **80%** y **95%**, y al agotarse; sigue
    reintentando y sube cuando haya espacio.
21. **Carpeta local desaparece**: **no tocar la nube**; avisar y dejar al usuario
    decidir qué hacer con la copia.
22. Nombres imposibles/rutas largas: se saltan y se reportan; nunca detienen la app.

## 7. Restauración

23. **Solo "todo de una vez"**, hacia **la carpeta original**; con progreso y
    cancelable.
24. **Colisión de nombres**: no toca los locales y avisa qué quedó sin restaurar.
25. **Papelera visible y deshacible desde la app**.
26. En equipo nuevo: elegir carpeta → si la cuenta ya tiene respaldo, **ofrece
    restaurar todo**.

## 8. Integración con el SO

27. **Autostart activado por defecto**, desactivable en ajustes.
28. **Instancia única**; al despertar de suspensión, revisa cambios acumulados.
29. ~~Actualizaciones automáticas y silenciosas~~ **MODIFICADO**: sin
    actualizaciones automáticas en v1; el desarrollador entrega cada versión a
    mano a los clientes.

## 9. Seguridad y privacidad

30. **Sin cifrado adicional** (HTTPS de por medio; quien entre a la cuenta lee todo).
31. **Nada sale del equipo**: cero telemetría; registros locales únicamente.
32. Los registros **nunca** contienen contenido de archivos ni credenciales.

## 10. Distribución

33. **Windows: instalador .exe** (sin actualizador integrado). **Linux: AppImage**.
34. **Sin firma de código en v1** (aviso de SmartScreen asumido).

## 11. Calidad

35. **"Lista" = 5 escenarios sin fallar**: subida confiable, sobrevive reinicios,
    papelera funciona (deshacer real), restauración completa, tolera fallos sin
    colgarse ni perder datos.
36. **Cobertura alta de pruebas automáticas**.
37. **Beta con 2–3 clientes de confianza** antes del lanzamiento general.

## 12. Fuera de la v1 (confirmado)

Bidireccionalidad · multiequipo · unidades externas/red · varias carpetas ·
historial de versiones · restauración parcial · cifrado adicional · telemetría ·
licencias online/servidor · firma de código · "Ver en Drive" · móvil/web.

## Decisiones técnicas

- **Stack: Flutter Desktop (Dart)**.
- **Gestión de estado: bloc** · **Inyección de dependencias: get_it** ·
  **Navegación: go_router**.
- Regla de trabajo: **toda librería nueva requiere aprobación explícita del
  product owner antes de agregarse**.
- Acceso a Drive: API REST v3 con token de refresco incrustado desde `.env`
  (detalle fino se define durante la implementación).

## Puntos abiertos

- Valores por defecto propuestos, ajustables: intervalo por defecto (15 min),
  reintentos de archivo bloqueado (3), ventana de estabilidad (2 min entre 1–3),
  umbrales de cuota (80/95).
