# Sonora

Reproductor de música local para Android, pensado y probado en un Samsung Galaxy A54.

## Funciones

- Biblioteca de archivos `.flac`, `.mp3`, `.mp4` y `.m4a` con audio dentro de una carpeta elegida. Los MP4 solo se reproducen como audio; el códec depende del archivo y del dispositivo.
- Pestañas de canciones, álbumes, artistas y carpeta.
- Carátulas consultadas a 600 px y calidad 100, con renderizado de alta calidad y caché limitada.
- Favoritos, historial local, recuento de escuchas y accesos rápidos para aleatorio y más escuchadas.
- Playlists personalizadas: crear, renombrar y eliminar listas; agregar o quitar canciones, buscar dentro de cada lista y reordenarlas. Se guardan localmente y están disponibles desde el menú lateral.
- Cola con controles de reproducción, aleatorio y repetición, accesible desde el menú lateral.
- Cola editable: agregar canciones para reproducir a continuación, reordenar, quitar pistas y vaciarla.
- Recuerda la cola y la posición actual al cerrar; al volver, restaura la sesión pausada para que puedas continuar cuando quieras.
- Now Playing con fondos seleccionables (desenfocado, degradado o color de acento) y datos técnicos disponibles del archivo.
- En Now Playing, desliza horizontalmente sobre la carátula o los datos de la canción para cambiar de pista.
- Reintentos breves del escaneo cuando Android aún no devuelve archivos justo después de conceder permisos.
- Notificación multimedia y reproducción en segundo plano.
- Ecualizador nativo de Android con preajustes Flat, Bass Boost, Rock, Pop y Vocal; bandas y preferencias personalizadas guardadas.
- Cola gapless de just_audio y fundido suave opcional mediante una rampa de volumen configurable.
- Sleep Timer de 15, 30, 45 o 60 minutos, o al terminar la canción actual, con fade-out de 30 segundos y cancelación desde Now Playing.
- Modo AMOLED y solicitud de 60 Hz, 120 Hz o frecuencia automática.
- Temas oscuro/claro, colores de acento y preferencias guardadas.
- Ajuste para omitir canciones de menos de 30 segundos y opción para preparar la cola.

El ajuste de frecuencia solicita un modo de pantalla a Android; no garantiza 120 FPS y el sistema puede limitarlo por ahorro de batería, brillo o políticas del dispositivo. El ecualizador usa el efecto nativo incluido en just_audio y depende de la disponibilidad del dispositivo. El fundido reduce y recupera el volumen con un solo reproductor; no mezcla dos canciones simultáneamente. El bitrate mostrado es una estimación media por tamaño/duración; el sample rate se obtiene del encabezado cuando es posible. La reproducción sin pausas y FLAC también dependen de los códecs y archivos disponibles en Android. Preparar toda la cola puede consumir más memoria.

## Organización del código

- `lib/main.dart`: inicialización del audio y arranque de la app.
- `lib/music_home_page.dart`: biblioteca, pestañas, cola, sesión y mini reproductor.
- `lib/playback_queue.dart` y `lib/playback_session.dart`: operaciones de cola y estado de reproducción guardado.
- `lib/playlist_model.dart` y `lib/playlist_library_page.dart`: modelo persistente y gestión de playlists.
- `lib/music_settings_page.dart`: pantalla de ajustes.
- `lib/now_playing_page.dart`: pantalla de reproducción completa.
- `lib/equalizer_presets.dart`, `lib/equalizer_state.dart`, `lib/sleep_timer_state.dart` y `lib/playback_transition_controller.dart`: preajustes del ecualizador, estado de bandas y temporizador/transiciones de volumen.
- `lib/artwork_widgets.dart`, `lib/audio_file_info.dart`, `lib/marquee_text.dart`, `lib/ui_helpers.dart` y `lib/format_duration.dart`: widgets y utilidades compartidos.
- Los iconos de inicio Android usan las variantes por densidad y el icono adaptativo/monocromático de `android/app/src/main/res`.


En la app, selecciona tu carpeta de música y concede el permiso de audio y notificaciones cuando Android los solicite.
