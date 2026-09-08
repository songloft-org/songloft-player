// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get updateFoundTitle => 'Actualización disponible';

  @override
  String updateFoundBody(String version) {
    return 'Hay una nueva versión $version disponible. ¿Descargar y actualizar ahora?';
  }

  @override
  String get updateComponentsHeader =>
      'Las siguientes actualizaciones están disponibles. ¿Descargar y actualizar ahora?';

  @override
  String updateComponentFrontend(String version) {
    return 'Parche de frontend $version';
  }

  @override
  String updateComponentBackend(String version) {
    return 'Parche de backend $version';
  }

  @override
  String get updateRestartInterrupt =>
      'La app se reiniciará, lo que puede interrumpir la reproducción.';

  @override
  String get updateActionDownload => 'Descargar y actualizar';

  @override
  String get updateActionLater => 'Más tarde';

  @override
  String get updateActionIgnore => 'Ignorar esta versión';

  @override
  String get updateDownloading => 'Descargando actualización…';

  @override
  String get updateReadyTitle => 'Actualización completada';

  @override
  String get updateReadyBody =>
      'La actualización se ha descargado. Reinicia la app para aplicarla.';

  @override
  String get updateActionRestartNow => 'Reiniciar ahora';

  @override
  String get updateFailed => 'Error en la actualización, inténtalo de nuevo';

  @override
  String get updateIncompatibleTitle => 'Se requiere una versión nueva';

  @override
  String updateIncompatibleBody(String version) {
    return 'La versión $version incluye cambios que no se pueden actualizar en caliente. Descarga el instalador más reciente desde Ajustes.';
  }

  @override
  String get updateActionGoDownload => 'Ir a descargar';

  @override
  String get language => 'Idioma';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Seguir sistema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeModeTitle => 'Modo de tema';

  @override
  String get themeModeSubtitle => 'Elige la apariencia de la app';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themePackTitle => 'Paquetes de tema';

  @override
  String get themePackSubtitle =>
      'Personaliza colores y estilos visuales con paquetes de tema';

  @override
  String get themePackImport => 'Importar';

  @override
  String get themePackRestoreDefault => 'Restaurar predeterminado';

  @override
  String get themePackEmpty => 'No hay paquetes de tema instalados';

  @override
  String get themePackLoadError => 'No se pudieron cargar los paquetes de tema';

  @override
  String get themePackImportSuccess =>
      'Paquete de tema importado correctamente';

  @override
  String get themePackImportError => 'Error al importar';

  @override
  String get themePackDeleteConfirmTitle => 'Eliminar paquete de tema';

  @override
  String themePackDeleteConfirmContent(String name) {
    return '¿Seguro que quieres eliminar \"$name\"?';
  }

  @override
  String get themeCatalogTitle => 'Temas en línea';

  @override
  String get themeCatalogRefresh => 'Actualizar';

  @override
  String get themeCatalogEmpty => 'No hay temas en línea disponibles';

  @override
  String get themeCatalogLoadError =>
      'No se pudieron cargar los temas en línea';

  @override
  String get themeCatalogInstall => 'Instalar';

  @override
  String get themeCatalogUpdate => 'Actualizar';

  @override
  String get themeCatalogInstalled => 'Instalado';

  @override
  String themeCatalogInstallSuccess(String name) {
    return 'El tema \"$name\" se instaló correctamente';
  }

  @override
  String get themeCatalogInstallError => 'Error en la instalación';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonLoading => 'Cargando';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get errorNetworkFailed => 'Error de conexión de red';

  @override
  String get errorGeneric => 'Algo salió mal';

  @override
  String get deleteAlsoLocalFile => 'Eliminar también el archivo local';

  @override
  String get deleteIrreversible => 'Esta acción no se puede deshacer';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navPlaylists => 'Listas de reproducción';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get favoriteAdded => 'Añadido a favoritos';

  @override
  String get favoriteRemoved => 'Eliminado de favoritos';

  @override
  String get favoriteAddFailed => 'No se pudo añadir a favoritos';

  @override
  String get favoriteRemoveFailed => 'No se pudo quitar de favoritos';

  @override
  String get favorite => 'Favorito';

  @override
  String get unfavorite => 'Quitar favorito';

  @override
  String get commonCreate => 'Crear';

  @override
  String commonConfirmWithCount(int count) {
    return 'Aceptar ($count)';
  }

  @override
  String get commonLoadFailed => 'No se pudo cargar';

  @override
  String commonLoadFailedDetail(String error) {
    return 'No se pudo cargar: $error';
  }

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectFolder => 'Seleccionar carpeta';

  @override
  String get more => 'Más';

  @override
  String get expand => 'Expandir';

  @override
  String get collapse => 'Contraer';

  @override
  String get songTypeLocal => 'Local';

  @override
  String get songTypeRemote => 'Remota';

  @override
  String get songTypeRadio => 'Radio';

  @override
  String get filterAll => 'Todas';

  @override
  String get pickerSelectSongs => 'Seleccionar canciones';

  @override
  String get pickerSearchHint => 'Buscar canciones, artistas o álbumes';

  @override
  String get pickerNoMatchInFolder =>
      'No hay canciones que coincidan en esta carpeta';

  @override
  String get pickerNoMatch => 'No hay canciones que coincidan';

  @override
  String get pickerNoSongsInFolder => 'No hay canciones en esta carpeta';

  @override
  String get pickerNoSongs => 'Aún no hay canciones';

  @override
  String pickerFetchListFailed(String error) {
    return 'No se pudo obtener la lista: $error';
  }

  @override
  String get pickerSelectingAll => 'Seleccionando todo...';

  @override
  String pickerDeselectAllWithCount(int count) {
    return 'Deseleccionar todo ($count seleccionadas)';
  }

  @override
  String pickerSelectAllCount(int count) {
    return 'Seleccionar todas $count';
  }

  @override
  String get loadFailedTapRetry => 'No se pudo cargar, toca para reintentar';

  @override
  String get loadedAllHint => '— Todo cargado —';

  @override
  String get addToPlaylist => 'Añadir a lista de reproducción';

  @override
  String get newPlaylist => 'Nueva lista de reproducción';

  @override
  String get playlistNameLabel => 'Nombre de la lista';

  @override
  String get noPlaylists => 'Aún no hay listas de reproducción';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String get addFailed => 'No se pudo añadir';

  @override
  String addFailedDetail(String error) {
    return 'No se pudo añadir: $error';
  }

  @override
  String addedToPlaylist(int added, String name) {
    return 'Se añadieron $added canción(es) a \"$name\"';
  }

  @override
  String addedToPlaylistWithSkip(int added, String name, int skipped) {
    return 'Se añadieron $added a \"$name\", se omitieron $skipped';
  }

  @override
  String createdPlaylistAdded(String name, int added) {
    return 'Lista \"$name\" creada con $added canción(es) añadidas';
  }

  @override
  String createdPlaylistWithSkip(String name, int added, int skipped) {
    return 'Lista \"$name\" creada con $added añadidas, $skipped omitidas';
  }

  @override
  String get createPlaylistFailed =>
      'No se pudo crear la lista de reproducción';

  @override
  String createPlaylistFailedDetail(String error) {
    return 'No se pudo crear la lista: $error';
  }

  @override
  String get selectAllFiles => 'Seleccionar todos los archivos';

  @override
  String get allSongs => 'Todas las canciones';

  @override
  String get musicDirEmpty => 'El directorio de música está vacío';

  @override
  String get dirEmpty => 'El directorio está vacío';

  @override
  String loadDirFailed(String error) {
    return 'No se pudo cargar el directorio: $error';
  }

  @override
  String get githubProxyDirect => 'Directo (sin proxy)';

  @override
  String coreErrorConnectionTimeout(String target) {
    return 'No se pudo conectar con $target (tiempo de espera agotado). Comprueba: (1) que el servicio backend esté en ejecución, (2) que la URL y el puerto sean correctos, (3) si accedes vía ZeroTier/VPN, que la VPN esté conectada y el \"enrutamiento global\" activado.';
  }

  @override
  String coreErrorConnectionFailed(String target) {
    return 'No se pudo conectar con $target. Comprueba que la URL sea correcta; si accedes vía ZeroTier/VPN, asegúrate de que la VPN esté activada.';
  }

  @override
  String get coreErrorBadCertificate => 'Falló la verificación del certificado';

  @override
  String get coreErrorRequestCancelled => 'Solicitud cancelada';

  @override
  String get coreErrorUnknownNetwork => 'Error de red desconocido';

  @override
  String get coreErrorNoResponse => 'El servidor no respondió';

  @override
  String get coreErrorRequestFailed => 'La solicitud falló';

  @override
  String get coreErrorUnauthorized =>
      'Tu sesión ha caducado, inicia sesión de nuevo';

  @override
  String get coreErrorForbidden => 'Acceso denegado';

  @override
  String get coreErrorNotFound => 'El recurso solicitado no existe';

  @override
  String get coreErrorServer =>
      'Error del servidor, inténtalo de nuevo más tarde';

  @override
  String get coreNotFoundPageTitle => 'Página no encontrada';

  @override
  String get coreBackToHome => 'Volver al inicio';

  @override
  String get coreNotificationChannel => 'Control de reproducción de Songloft';

  @override
  String get coreVersionDev => 'Compilación de desarrollo';

  @override
  String get jspluginManagerTitle => 'Gestión de plugins JS';

  @override
  String get jspluginManagerSubtitle => 'Administra los plugins JS instalados';

  @override
  String get jspluginUploadPlugin => 'Subir plugin';

  @override
  String get jspluginUpdateAll => 'Actualizar todos';

  @override
  String get jspluginCleanupData => 'Limpiar datos';

  @override
  String get jspluginCleanupOrphanTitle => 'Limpiar datos huérfanos';

  @override
  String get jspluginCleanupOrphanContent =>
      'Se eliminarán los datos de almacenamiento persistente que dejaron los plugins desinstalados. Esta acción no se puede deshacer.';

  @override
  String get jspluginCleanup => 'Limpiar';

  @override
  String jspluginCleanupFailed(String error) {
    return 'Error al limpiar: $error';
  }

  @override
  String get jspluginNoInstalled => 'No hay plugins JS instalados';

  @override
  String jspluginPickFileFailed(String error) {
    return 'No se pudo elegir el archivo: $error';
  }

  @override
  String get jspluginCannotReadFile =>
      'No se pueden leer los datos del archivo';

  @override
  String get jspluginCannotGetPath => 'No se pudo obtener la ruta del archivo';

  @override
  String jspluginUploadSuccess(int count) {
    return '$count plugin(s) subido(s) correctamente';
  }

  @override
  String jspluginUploadPartial(int success, int failed, String error) {
    return '$success correctos, $failed fallidos\n$error';
  }

  @override
  String jspluginUploadFailed(String error) {
    return 'Error al subir: $error';
  }

  @override
  String get jspluginUploadDialogTitle => 'Subir plugin JS';

  @override
  String get jspluginSelectFileSemantics =>
      'Selecciona un archivo de plugin para subir';

  @override
  String get jspluginTapToSelectFile => 'Toca para seleccionar un archivo';

  @override
  String get jspluginUploadHint =>
      'Compatible con el formato .jsplugin.zip; subir un plugin con el mismo nombre sobrescribe la versión existente (actualización manual)';

  @override
  String get jspluginRemove => 'Quitar';

  @override
  String get jspluginUploading => 'Subiendo...';

  @override
  String get jspluginUpload => 'Subir';

  @override
  String jspluginOperationFailed(String error) {
    return 'La operación falló: $error';
  }

  @override
  String jspluginCannotOpenLink(String url) {
    return 'No se puede abrir el enlace: $url';
  }

  @override
  String get jspluginForceUpdateSuccess => 'Plugin actualizado a la fuerza';

  @override
  String jspluginForceUpdateFailed(String error) {
    return 'Error en la actualización forzada: $error';
  }

  @override
  String get jspluginConfirmDelete => 'Confirmar eliminación';

  @override
  String jspluginDeleteConfirmContent(String name) {
    return '¿Seguro que quieres eliminar el plugin \"$name\"?';
  }

  @override
  String get jspluginKeepData => 'Conservar datos del plugin';

  @override
  String get jspluginKeepDataSubtitle =>
      'Conserva los datos de almacenamiento de archivos para reinstalarlo fácilmente después';

  @override
  String get jspluginDeleted => 'Plugin eliminado';

  @override
  String jspluginDeleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String jspluginAuthor(String author) {
    return 'Autor: $author';
  }

  @override
  String get jspluginOpenHomepageSemantics => 'Abrir la página del plugin';

  @override
  String get jspluginStatusError => 'Error';

  @override
  String get jspluginStatusEnabled => 'Activado';

  @override
  String get jspluginStatusDisabled => 'Desactivado';

  @override
  String get jspluginMoreActions => 'Más acciones';

  @override
  String get jspluginOpenHomepage => 'Abrir página de inicio';

  @override
  String get jspluginKeepAlive => 'Mantener en ejecución';

  @override
  String get jspluginCancelKeepAlive => 'Dejar de mantener en ejecución';

  @override
  String get jspluginCheckUpdate => 'Buscar actualizaciones';

  @override
  String get jspluginForceUpdate => 'Forzar actualización';

  @override
  String get jspluginUpdate => 'Actualizar';

  @override
  String get jspluginCheckUpdateTimeout =>
      'La comprobación de actualizaciones agotó el tiempo. Prueba a cambiar de proxy e inténtalo de nuevo.';

  @override
  String jspluginCheckUpdateFailed(String error) {
    return 'Error al buscar actualizaciones: $error';
  }

  @override
  String get jspluginUpdateSuccess => 'Plugin actualizado correctamente';

  @override
  String jspluginUpdateFailed(String error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get jspluginUpdateTimeout =>
      'La actualización agotó el tiempo. Inténtalo de nuevo.';

  @override
  String jspluginUpdateDialogTitle(String name) {
    return 'Actualizar plugin - $name';
  }

  @override
  String get jspluginCheckingUpdate => 'Buscando actualizaciones...';

  @override
  String get jspluginDownloadingUpdate =>
      'Descargando y actualizando el plugin...';

  @override
  String get jspluginDoNotCloseDialog => 'No cierres este diálogo';

  @override
  String get jspluginAlreadyLatest => 'Ya está actualizado';

  @override
  String jspluginCurrentVersion(String version) {
    return 'Versión actual: $version';
  }

  @override
  String get jspluginNewVersionFound => 'Hay una versión nueva disponible';

  @override
  String get jspluginRecheck => 'Volver a comprobar';

  @override
  String get jspluginUpdateNow => 'Actualizar ahora';

  @override
  String get jspluginClose => 'Cerrar';

  @override
  String jspluginBatchUpdateFailed(String error) {
    return 'Error en la actualización por lotes: $error';
  }

  @override
  String get jspluginBatchUpdateTimeout =>
      'La actualización por lotes agotó el tiempo. Inténtalo de nuevo.';

  @override
  String get jspluginBatchUpdating =>
      'Comprobando y actualizando todos los plugins...';

  @override
  String get jspluginStatUpdated => 'Actualizado';

  @override
  String get jspluginStatFailed => 'Fallido';

  @override
  String get jspluginStatSkipped => 'Actualizado';

  @override
  String get jspluginUpdateFailedShort => 'Error en la actualización';

  @override
  String jspluginVersionLatest(String version) {
    return 'v$version ya está actualizado';
  }

  @override
  String get jspluginStartUpdate => 'Iniciar actualización';

  @override
  String jspluginForceUpdateDialogTitle(String name) {
    return 'Forzar actualización - $name';
  }

  @override
  String get jspluginForceUpdateContent =>
      'Esto ignora la comprobación de versión y vuelve a descargar e instalar el plugin.';

  @override
  String get jspluginConfirmUpdate => 'Confirmar actualización';

  @override
  String get jspluginStoreTitle => 'Tienda de plugins';

  @override
  String get jspluginRefreshList => 'Actualizar lista de plugins';

  @override
  String get jspluginManageRegistries => 'Administrar fuentes';

  @override
  String get jspluginNoRegistries => 'Aún no hay fuentes añadidas';

  @override
  String get jspluginNoRegistriesHint =>
      'Añade una fuente para explorar e instalar plugins';

  @override
  String get jspluginAddRegistry => 'Añadir fuente';

  @override
  String get jspluginRegistry => 'Fuente';

  @override
  String get jspluginOfficial => 'Oficial';

  @override
  String get jspluginAllSources => 'Todas';

  @override
  String get jspluginAutoUpdate => 'Autoactualizar plugins';

  @override
  String get jspluginAutoUpdateHint =>
      'Comprueba y actualiza periódicamente los plugins instalados en segundo plano';

  @override
  String get jspluginSearchHint => 'Buscar plugins...';

  @override
  String get jspluginLoadingList => 'Cargando lista de plugins…';

  @override
  String get jspluginNoMatch => 'No se encontraron plugins que coincidan';

  @override
  String get jspluginRegistryEmpty => 'Esta fuente no tiene plugins';

  @override
  String jspluginRegistryWarningsSummary(int count) {
    return 'No se pudieron cargar algunos datos de plugins (avisos: $count)';
  }

  @override
  String get jspluginRegistryWarningsTitle => 'Avisos de carga';

  @override
  String get jspluginRegistryWarningsDetails => 'Ver detalles de los avisos';

  @override
  String get jspluginPrevPage => 'Página anterior';

  @override
  String get jspluginNextPage => 'Página siguiente';

  @override
  String jspluginInstallFailed(String error) {
    return 'Error en la instalación: $error';
  }

  @override
  String get jspluginReinstall => 'Reinstalar';

  @override
  String jspluginUpdateTo(String version) {
    return 'Actualizar a v$version';
  }

  @override
  String get jspluginInstall => 'Instalar';

  @override
  String get jspluginOverwriteInstall => 'Reemplazar';

  @override
  String jspluginConflictBanner(String plugin) {
    return 'Entra en conflicto con $plugin instalado';
  }

  @override
  String get jspluginConflictDialogTitle => '¿Reemplazar el plugin instalado?';

  @override
  String jspluginConflictDialogBody(String entryPath, String plugin) {
    return 'El identificador \"$entryPath\" ya lo usa $plugin. Instalar este plugin lo reemplaza, y el reemplazo hereda los datos almacenados del plugin original. Esto no se puede deshacer.';
  }

  @override
  String get jspluginConflictDialogConfirm => 'Reemplazar';

  @override
  String jspluginSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get jspluginEditRegistry => 'Editar fuente';

  @override
  String get jspluginDeleteRegistry => 'Eliminar fuente';

  @override
  String get jspluginNameOptional => 'Nombre (opcional)';

  @override
  String get jspluginRegistryNameHint => 'Mi fuente de plugins';

  @override
  String get jspluginTokenOptional => 'Token (opcional)';

  @override
  String get jspluginSave => 'Guardar';

  @override
  String get jspluginAdd => 'Añadir';

  @override
  String get jspluginAuthConfigured => 'Autenticación configurada';

  @override
  String get jspluginGridTitle => 'Plugins JS';

  @override
  String get jspluginCleanupDone => 'Limpieza completada';

  @override
  String get libraryPlayFailed => 'Error de reproducción';

  @override
  String get libraryNoPlayableSongs => 'No hay canciones para reproducir';

  @override
  String libraryPlayingAllSongs(int total) {
    return 'Reproduciendo las $total canciones';
  }

  @override
  String get libraryDismissError => 'Descartar';

  @override
  String get libraryExitSelection => 'Salir de la selección';

  @override
  String librarySelectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String libraryDeleteWithCount(int count) {
    return 'Eliminar ($count)';
  }

  @override
  String get libraryDeselectAll => 'Deseleccionar todo';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryPlayAll => 'Reproducir todas';

  @override
  String get librarySort => 'Ordenar';

  @override
  String get librarySortAddedAt => 'Añadidas recientemente';

  @override
  String get librarySortFileTime => 'Fecha del archivo';

  @override
  String get libraryColumnTitle => 'Título';

  @override
  String get libraryColumnArtist => 'Artista';

  @override
  String get libraryColumnAlbum => 'Álbum';

  @override
  String get libraryColumnType => 'Tipo';

  @override
  String get libraryColumnDuration => 'Duración';

  @override
  String get librarySortFileSize => 'Tamaño de archivo';

  @override
  String get librarySelectMode => 'Selección múltiple';

  @override
  String get libraryMore => 'Más';

  @override
  String get libraryAddRemoteSong => 'Añadir canción remota';

  @override
  String get libraryAddRadio => 'Añadir radio';

  @override
  String get libraryHideHiddenSongs => 'Ocultar canciones ocultas';

  @override
  String get libraryShowHiddenSongs => 'Mostrar canciones ocultas';

  @override
  String get libraryCleanInvalidSongs => 'Limpiar canciones no válidas';

  @override
  String get librarySearchHint => 'Buscar canciones...';

  @override
  String get libraryNoMatchingSongs =>
      'No se encontraron canciones que coincidan';

  @override
  String get libraryEmpty => 'La biblioteca está vacía';

  @override
  String get libraryTryOtherKeywords => 'Prueba con otras palabras clave';

  @override
  String get libraryEmptyHint => 'Añade algunas canciones para empezar';

  @override
  String get libraryDeleteConfirmTitle => 'Confirmar eliminación';

  @override
  String get libraryDeleteConfirmContent =>
      '¿Seguro que quieres eliminar esta canción?';

  @override
  String get libraryCleanTitle => 'Limpiar canciones';

  @override
  String get libraryCleanContent =>
      'Esto limpiará los registros de canciones no válidos (como canciones locales cuyos archivos se han eliminado).';

  @override
  String libraryCleanedCount(int count) {
    return 'Se limpiaron $count canciones no válidas';
  }

  @override
  String get libraryClean => 'Limpiar';

  @override
  String get libraryBatchDeleteTitle => 'Eliminación por lotes';

  @override
  String libraryBatchDeleteContent(int count) {
    return '¿Seguro que quieres eliminar las $count canciones seleccionadas?';
  }

  @override
  String libraryDeletedCount(int count) {
    return 'Se eliminaron $count canciones';
  }

  @override
  String get libraryDeleteFailed => 'Error al eliminar';

  @override
  String librarySongCount(int count) {
    return '$count canciones';
  }

  @override
  String get libraryUnknownArtist => 'Artista desconocido';

  @override
  String get libraryUnknownAlbum => 'Álbum desconocido';

  @override
  String get libraryPlay => 'Reproducir';

  @override
  String get libraryEdit => 'Editar';

  @override
  String get libraryCustomizeViews => 'Personalizar vistas';

  @override
  String get libraryCustomizeViewsTooltip =>
      'Personaliza qué vistas se muestran y su orden';

  @override
  String get libraryViewsMinOne => 'Mantén al menos una vista visible';

  @override
  String get libraryViewPlaylistAll => 'Todas las listas de reproducción';

  @override
  String get categorySongsEmpty => 'No hay canciones en esta categoría';

  @override
  String get libraryViewGroupSongs => 'Canciones';

  @override
  String get libraryViewGroupCategories => 'Categorías';

  @override
  String get libraryViewGroupPlaylists => 'Listas de reproducción';

  @override
  String get libraryViewGroupMoveUp => 'Mover grupo hacia arriba';

  @override
  String get libraryViewGroupMoveDown => 'Mover grupo hacia abajo';

  @override
  String get libraryEditLocalSong => 'Editar canción local';

  @override
  String get libraryEditRadio => 'Editar radio';

  @override
  String get libraryEditRemoteSong => 'Editar canción remota';

  @override
  String get librarySave => 'Guardar';

  @override
  String get libraryFileInfoReadonly =>
      'Información del archivo (solo lectura)';

  @override
  String get libraryServerEndpointReadonly =>
      'Endpoint del servidor (solo lectura)';

  @override
  String get libraryReadonlyFile => 'Archivo';

  @override
  String get libraryReadonlyCover => 'Portada';

  @override
  String get libraryReadonlyLyric => 'Letras';

  @override
  String get libraryEditTitleLabel => 'Título *';

  @override
  String get libraryEditTitleRequired => 'Introduce un título';

  @override
  String get libraryEditArtistHint => 'Introduce un artista';

  @override
  String get libraryEditAlbumHint => 'Introduce un álbum';

  @override
  String get libraryRenameFileTitle => 'Renombrar archivo en sincronía';

  @override
  String get libraryRenameFileSubtitle =>
      'Renombra el archivo de audio local al nuevo título y escribe la etiqueta de título';

  @override
  String get libraryVideoToggleTitle => 'Contenido de video';

  @override
  String get libraryVideoToggleSubtitle =>
      'Este enlace contiene video; al activarlo, el reproductor muestra la imagen y la transmisión se envía como video';

  @override
  String get libraryEditSourceUrlLabel => 'URL de audio de origen *';

  @override
  String get libraryEditUrlLabel => 'URL *';

  @override
  String get libraryEditUrlHint => 'Introduce un enlace de audio';

  @override
  String get libraryEditUrlRequired => 'Introduce una URL';

  @override
  String get libraryEditUrlInvalid => 'Introduce una URL válida';

  @override
  String get libraryEditSourceCoverUrlLabel => 'URL de portada de origen';

  @override
  String get libraryEditCoverUrlLabel => 'URL de portada';

  @override
  String get libraryEditCoverUrlHint =>
      'Introduce un enlace de imagen de portada';

  @override
  String get libraryEditDurationLabel => 'Duración (segundos)';

  @override
  String get libraryEditDurationHint => 'Introduce la duración';

  @override
  String get libraryEditLyricRemoteUrlLabel => 'URL remota de letras';

  @override
  String get libraryEditLyricUrlLabel => 'URL de letras';

  @override
  String get libraryEditLyricUrlHint => 'Introduce un enlace de API de letras';

  @override
  String get libraryCoverPreview => 'Vista previa de portada:';

  @override
  String get libraryCopied => 'Copiado';

  @override
  String get libraryCopy => 'Copiar';

  @override
  String get librarySaveSuccess => 'Guardado correctamente';

  @override
  String get libraryAddSuccess => 'Añadido correctamente';

  @override
  String libraryOperationFailed(String error) {
    return 'La operación falló: $error';
  }

  @override
  String get libraryErrorBadRequest => 'Parámetros de solicitud no válidos';

  @override
  String get libraryErrorUnauthorized =>
      'No autorizado, inicia sesión de nuevo';

  @override
  String get libraryErrorForbidden =>
      'No tienes permiso para realizar esta acción';

  @override
  String get libraryErrorNotFound => 'Canción no encontrada';

  @override
  String get libraryErrorServer =>
      'Error del servidor, inténtalo de nuevo más tarde';

  @override
  String libraryErrorRequestFailed(int code) {
    return 'La solicitud falló: $code';
  }

  @override
  String get libraryErrorTimeout =>
      'Se agotó el tiempo de conexión de red, comprueba tu red';

  @override
  String get libraryErrorConnection =>
      'Falló la conexión de red, comprueba tu red';

  @override
  String libraryErrorNetwork(String message) {
    return 'Error de red: $message';
  }

  @override
  String get libraryFavoritePlaylistNotFound =>
      'La lista de favoritos no existe';

  @override
  String get libraryRadioFavoritePlaylistNotFound =>
      'La lista de radios favoritas no existe';

  @override
  String get homeEmptyPlaylists => 'Aún no hay listas de reproducción';

  @override
  String get homeEmptyPlaylistsSubtitle =>
      'Crea tu primera lista para empezar a coleccionar música';

  @override
  String get homeCreatePlaylist => 'Crear lista de reproducción';

  @override
  String get homeMyPlaylists => 'Mis listas de reproducción';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get homeMyRadios => 'Mis radios';

  @override
  String get homeLoadingSlowRetrying => 'La red está lenta, reintentando…';

  @override
  String get homeGreetingLateNight => 'Es tarde';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingNoon => 'Buenas tardes';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String get homeTvGreetingLateNight => 'Es tarde, ¿qué tal algo de música?';

  @override
  String get homeOpenPlaylist => 'Abrir lista de reproducción';

  @override
  String homeOpenPlaylistNamed(String name) {
    return 'Abrir lista de reproducción $name';
  }

  @override
  String homeSongCountShort(int count) {
    return '$count canciones';
  }

  @override
  String homeSongCount(int count) {
    return '$count canciones';
  }

  @override
  String get homeStatSongs => 'canciones en la biblioteca';

  @override
  String homeStatDurationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String homeStatDurationM(int minutes) {
    return '$minutes min';
  }

  @override
  String homeStatSize(String size) {
    return '$size en disco';
  }

  @override
  String get homeTvLocalMusic => 'Música local';

  @override
  String get homeTvPlaylist => 'Listas de reproducción';

  @override
  String get homeTvEmptySubtitle =>
      'Usa la navegación rápida para explorar la música local';

  @override
  String homeHeroSemanticLabel(String name, int count) {
    return '$name - $count canciones';
  }

  @override
  String get homeNowPlaying => 'Reproduciendo ahora';

  @override
  String get homeRecommendedPlaylist => 'Recomendadas';

  @override
  String get homePlayNow => 'Reproducir ahora';

  @override
  String get homePluginLoadTimeout =>
      'La página agotó el tiempo de carga. Comprueba si el plugin está disponible o tu conexión de red.';

  @override
  String get homePluginClose => 'Cerrar';

  @override
  String get homePluginOpenInBrowser => 'Abrir en el navegador';

  @override
  String get homePluginLoadFailed => 'No se pudo cargar la página';

  @override
  String homePluginLoadFailedHttp(String status, String detail) {
    return 'No se pudo cargar la página: HTTP $status$detail';
  }

  @override
  String get homePluginUnknownError => 'Error desconocido';

  @override
  String get homePluginWebOpenInNewTab =>
      'En la web, abre el plugin en una pestaña nueva';

  @override
  String get authLogin => 'Iniciar sesión';

  @override
  String get authTvSubtitle => 'Inicia sesión en Songloft con tu cuenta';

  @override
  String get authLoginToContinue => 'Inicia sesión para continuar';

  @override
  String get authTagline => 'Servicio de música local autogestionado';

  @override
  String get authUsername => 'Nombre de usuario';

  @override
  String get authUsernameHint => 'Introduce el nombre de usuario';

  @override
  String get authUsernameRequired => 'Introduce tu nombre de usuario';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authPasswordHint => 'Introduce la contraseña';

  @override
  String get authPasswordRequired => 'Introduce tu contraseña';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authApiUrl => 'Dirección de la API';

  @override
  String get authApiUrlRequired => 'Introduce la dirección de la API';

  @override
  String get authInvalidUrl =>
      'Introduce una URL válida (que empiece por http:// o https://)';

  @override
  String get authServer => 'Servidor';

  @override
  String get authTvPressToLogin => 'Pulsa OK para iniciar sesión';

  @override
  String get authUseLocalMode => 'Usar modo local';

  @override
  String get authAgreePrefix => 'He leído y acepto los ';

  @override
  String get authTermsAndPrivacy =>
      'Términos del servicio y política de privacidad';

  @override
  String get authPleaseAgreeTerms =>
      'Primero lee y acepta los Términos y la Política de privacidad';

  @override
  String get authTermsTitle => 'Términos del servicio y política de privacidad';

  @override
  String authCopyright(int year) {
    return '© $year Songloft';
  }

  @override
  String get authAutoLoggingIn => 'Iniciando sesión automáticamente…';

  @override
  String get authStartingLocalBackend => 'Iniciando backend local…';

  @override
  String get authPreparing => 'Preparando…';

  @override
  String get authConnecting => 'Conectando…';

  @override
  String get authLoggingIn => 'Iniciando sesión…';

  @override
  String authAutoLoginFailed(String error) {
    return 'Error en el inicio de sesión automático: $error';
  }

  @override
  String authLocalModeFailed(String error) {
    return 'No se pudo iniciar el modo local: $error';
  }

  @override
  String authLoginFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get authSessionExpired =>
      'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get authNoRefreshToken => 'No hay token de actualización disponible';

  @override
  String get dlnaCast => 'Transmitir';

  @override
  String get dlnaCasting => 'Transmitiendo';

  @override
  String get dlnaDisconnect => 'Desconectar';

  @override
  String get dlnaConnected => 'Conectado';

  @override
  String get dlnaSearching => 'Buscando dispositivos...';

  @override
  String get dlnaSearchingLan => 'Buscando dispositivos en la red local...';

  @override
  String get dlnaNoDevices => 'No se encontraron dispositivos DLNA';

  @override
  String get startupStarting => 'Iniciando…';

  @override
  String get startupStartingLocalBackend => 'Iniciando backend local…';

  @override
  String get startupConnectingLocalBackend =>
      'Conectando con el backend local…';

  @override
  String startupConnectingTo(String target) {
    return 'Conectando con $target…';
  }

  @override
  String get playerModeOrder => 'En orden';

  @override
  String get playerModeLoop => 'Repetir todo';

  @override
  String get playerModeSingle => 'Repetir una';

  @override
  String get playerModeRandom => 'Aleatorio';

  @override
  String get playerModeSinglePlay => 'Reproducir una vez';

  @override
  String get playerSpeed => 'Velocidad';

  @override
  String get playerSpeedTitle => 'Velocidad de reproducción';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get playerClose => 'Cerrar';

  @override
  String get playerSleepTimer => 'Temporizador de sueño';

  @override
  String playerSleepTimerWithStatus(String status) {
    return 'Temporizador de sueño: $status';
  }

  @override
  String get playerSleepTimerCancel => 'Cancelar temporizador';

  @override
  String get playerSleepTimerByDuration => 'Por duración';

  @override
  String playerHours(int count) {
    return '$count h';
  }

  @override
  String playerMinutes(int count) {
    return '$count min';
  }

  @override
  String get playerCustom => 'Personalizado';

  @override
  String get playerCustomDuration => 'Duración personalizada';

  @override
  String get playerUnitMinutes => 'min';

  @override
  String get playerSleepTimerBySongs => 'Por canciones';

  @override
  String playerSongsUnit(int count) {
    return '$count canciones';
  }

  @override
  String get playerCustomSongCount => 'Número de canciones personalizado';

  @override
  String get playerUnitSongs => 'canciones';

  @override
  String playerRemainingSongs(int count) {
    return 'Quedan $count canciones';
  }

  @override
  String get playerEnterNumber => 'Introduce un número';

  @override
  String get playerEnterValidInteger => 'Introduce un número entero válido';

  @override
  String playerEnterIntegerInRange(int min, int max) {
    return 'Introduce un número entero entre $min y $max';
  }

  @override
  String get playerBack => 'Atrás';

  @override
  String get playerNowPlaying => 'Reproduciendo ahora';

  @override
  String get playerNoContent => 'No se está reproduciendo nada';

  @override
  String get playerUnknownArtist => 'Artista desconocido';

  @override
  String get playerPlayMode => 'Modo de reproducción';

  @override
  String get playerVolumeDown => 'Bajar volumen';

  @override
  String get playerVolumeUp => 'Subir volumen';

  @override
  String get playerPrevious => 'Anterior';

  @override
  String get playerNext => 'Siguiente';

  @override
  String get playerPlaylist => 'Lista de reproducción';

  @override
  String get playerBuffering => 'Buffering';

  @override
  String get playerCaching => 'Almacenando en caché, espera…';

  @override
  String get playerPause => 'Pausa';

  @override
  String get playerPlay => 'Reproducir';

  @override
  String get playerSeekHint => '← → Buscar';

  @override
  String get playerProgress => 'Progreso de reproducción';

  @override
  String get playerQueueTitle => 'Cola de reproducción';

  @override
  String get playerClearPlaylist => 'Vaciar lista de reproducción';

  @override
  String get playerQueueEmpty => 'La cola está vacía';

  @override
  String get playerDrawerEmptyHint =>
      'Añade canciones para empezar a reproducir';

  @override
  String get playerQueueEmptyHint =>
      'Añade canciones a la cola para empezar a reproducir';

  @override
  String playerRemovedSong(String title) {
    return 'Se quitó \"$title\"';
  }

  @override
  String get playerClearQueueTitle => 'Vaciar cola de reproducción';

  @override
  String get playerClearQueueConfirm => '¿Vaciar la cola de reproducción?';

  @override
  String get playerClear => 'Vaciar';

  @override
  String get playerRemoveFromPlaylist => 'Quitar de la lista de reproducción';

  @override
  String get playerRemoveFromQueue => 'Quitar de la cola';

  @override
  String get playerMute => 'Silenciar';

  @override
  String get playerUnmute => 'Reactivar sonido';

  @override
  String playerVolumePercent(int value) {
    return 'Volumen $value%';
  }

  @override
  String get playerVolume => 'Volumen';

  @override
  String get playerCloseVolumePanel => 'Cerrar panel de volumen';

  @override
  String get playerOpenFullPlayer => 'Abrir reproductor a pantalla completa';

  @override
  String get playerEqualizer => 'Ecualizador';

  @override
  String get playerAudioTrack => 'Pista de audio';

  @override
  String get playerSelectAudioTrack => 'Seleccionar pista de audio';

  @override
  String playerAudioTrackNumbered(int index) {
    return 'Pista $index';
  }

  @override
  String get playerLyrics => 'Letras';

  @override
  String get playerCollapse => 'Contraer';

  @override
  String get playerSubtitleOn => 'Mostrar subtítulos';

  @override
  String get playerSubtitleOff => 'Ocultar subtítulos';

  @override
  String get playerEnterFullscreen => 'Pantalla completa';

  @override
  String get playerExitFullscreen => 'Salir de pantalla completa';

  @override
  String get playerSleepTimerOn => 'Temporizador de sueño (activado)';

  @override
  String get playerDeleteCurrentSong => 'Eliminar canción actual';

  @override
  String get playerExpandPlayer => 'Expandir reproductor';

  @override
  String get playerBufferingSemantic => 'Buffering';

  @override
  String get playerLyricsLoading => 'Cargando letras...';

  @override
  String get playerLyricsLoadFailed => 'No se pudieron cargar las letras';

  @override
  String get playerLyricsEmpty => 'Sin letras';

  @override
  String get playerLyricsSeekTo => 'Ir a esta línea de la letra';

  @override
  String get playerAdjustLyrics => 'Ajustar letras';

  @override
  String get playerLyricsRefetch => 'Volver a buscar letras';

  @override
  String get playerEqNotSupported =>
      'El ecualizador no es compatible con esta plataforma';

  @override
  String get playerEqPresetFlat => 'Plano';

  @override
  String get playerEqPresetRock => 'Rock';

  @override
  String get playerEqPresetPop => 'Pop';

  @override
  String get playerEqPresetJazz => 'Jazz';

  @override
  String get playerEqPresetClassical => 'Clásica';

  @override
  String get playerEqPresetBassBoost => 'Refuerzo de graves';

  @override
  String get playerEqPresetTrebleBoost => 'Refuerzo de agudos';

  @override
  String get playerEqPresetVocal => 'Vocal';

  @override
  String get playerEqPresetCustom => 'Personalizado';

  @override
  String get playerLyricSavedWritten =>
      'Guardado y escrito en el archivo de audio';

  @override
  String get playerLyricSavedWriteFailed =>
      'Guardado en la base de datos, pero no se pudo escribir en el archivo de audio';

  @override
  String get playerLyricSavedDbOnly =>
      'Guardado en la base de datos (archivo no actualizado)';

  @override
  String playerSaveFailedDetail(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get playerDiscardChangesTitle => '¿Descartar cambios?';

  @override
  String get playerDiscardChangesContent =>
      'Tus cambios no se han guardado. ¿Salir de todos modos?';

  @override
  String get playerContinueEditing => 'Seguir editando';

  @override
  String get playerDiscard => 'Descartar';

  @override
  String get playerGlobalOffset => 'Desplazamiento global';

  @override
  String playerLyricOffsetSemantics(int value) {
    return 'Desplazamiento de letras $value ms';
  }

  @override
  String get playerOffsetHint =>
      'Consejo: si las letras aparecen demasiado pronto en general, usa un desplazamiento negativo (-); si aparecen tarde, usa uno positivo (+)';

  @override
  String get playerEmptyLine => '(línea vacía)';

  @override
  String playerLineOffset(String offset) {
    return 'Desplazamiento de línea $offset';
  }

  @override
  String get playerReset => 'Restablecer';

  @override
  String get playerSave => 'Guardar';

  @override
  String get playerNoLyricsToAdjust => 'No hay letras para ajustar';

  @override
  String get playerDeleteSongTitle => 'Eliminar canción';

  @override
  String playerDeleteSongConfirm(String title) {
    return '¿Eliminar \"$title\" de tu biblioteca?';
  }

  @override
  String get playerSongDeleted => 'Canción eliminada';

  @override
  String get playerDeleteFailed => 'Error al eliminar';

  @override
  String get playerUnknownSong => 'Canción desconocida';

  @override
  String playerPlayFailedNamed(String title) {
    return 'No se pudo reproducir \"$title\"';
  }

  @override
  String playerConsecutiveFailures(int count) {
    return '$count canciones seguidas no se pudieron reproducir. Reproducción detenida: comprueba tu conexión de red.';
  }

  @override
  String playerPlayFailedTryingNext(String title) {
    return 'No se pudo reproducir \"$title\", probando con la siguiente canción...';
  }

  @override
  String get playerPlayFailedNoOthers =>
      'Error de reproducción: no hay más canciones para reproducir';

  @override
  String get playerPlayFailedEndOfList =>
      'Error de reproducción: se llegó al final de la lista';

  @override
  String get playlistBack => 'Atrás';

  @override
  String get playlistSearch => 'Buscar';

  @override
  String get playlistSearchHint => 'Buscar canciones...';

  @override
  String get playlistListSearchHint => 'Buscar listas de reproducción...';

  @override
  String get playlistNoMatching => 'No se encontraron listas que coincidan';

  @override
  String get playlistTryOtherKeywords => 'Prueba con otras palabras clave';

  @override
  String get playlistFilterNormal => 'Listas de reproducción';

  @override
  String get playlistFilterRadio => 'Radios';

  @override
  String get playlistFilterRemote => 'Listas remotas';

  @override
  String get playlistFilterLocal => 'Listas locales';

  @override
  String get playlistMultiSelect => 'Selección múltiple';

  @override
  String get playlistMore => 'Más';

  @override
  String get playlistDone => 'Hecho';

  @override
  String get playlistSort => 'Ordenar';

  @override
  String get playlistSortModeTitle => 'Reordenar listas de reproducción';

  @override
  String get playlistSortSaved => 'Orden guardado';

  @override
  String get playlistSortSaveFailed => 'No se pudo guardar el orden';

  @override
  String get playlistSortFailed => 'Error al ordenar';

  @override
  String get playlistAlreadySortedSongs =>
      'Las canciones ya están en este orden';

  @override
  String get playlistAlreadySortedPlaylists =>
      'Las listas ya están en este orden';

  @override
  String get playlistSortedByNameAsc => 'Ordenadas por nombre (A→Z)';

  @override
  String get playlistSortedByNameDesc => 'Ordenadas por nombre (Z→A)';

  @override
  String get playlistSortedByNumber => 'Ordenadas por prefijo numérico';

  @override
  String get playlistSortCustom => 'Orden personalizado';

  @override
  String get playlistSortRecentlyAdded => 'Añadidas recientemente';

  @override
  String get playlistSortFileTime => 'Fecha del archivo';

  @override
  String get playlistSortTitle => 'Título';

  @override
  String get playlistSortArtist => 'Artista';

  @override
  String get playlistSortDuration => 'Duración';

  @override
  String get playlistSortFileSize => 'Tamaño de archivo';

  @override
  String get playlistSortNameAsc => 'Ordenar por nombre A→Z';

  @override
  String get playlistSortNameDesc => 'Ordenar por nombre Z→A';

  @override
  String get playlistSortNumberPrefix => 'Ordenar por prefijo numérico';

  @override
  String get playlistSortManual => 'Ordenar manualmente';

  @override
  String get playlistPlayAll => 'Reproducir todas';

  @override
  String get playlistAddSongs => 'Añadir canciones';

  @override
  String get playlistAddSongsFailed => 'No se pudieron añadir las canciones';

  @override
  String playlistAddedWithSkipped(int added, int skipped) {
    return 'Se añadieron $added, se omitieron $skipped (ya existen o tipo incompatible)';
  }

  @override
  String playlistAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $count canciones',
      one: 'Se añadió 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get playlistLoadMoreRetry =>
      'No se pudo cargar más, toca para reintentar';

  @override
  String playlistAllLoaded(int count) {
    return '— Todo cargado ($count) —';
  }

  @override
  String get playlistDeselectAll => 'Deseleccionar todo';

  @override
  String get playlistRemove => 'Quitar';

  @override
  String get playlistRemoveFromPlaylist => 'Quitar de la lista de reproducción';

  @override
  String get playlistDeleteFromLibrary => 'Eliminar de la biblioteca';

  @override
  String playlistActionsCount(int count) {
    return 'Acciones ($count)';
  }

  @override
  String get playlistBatchRemoveTitle => 'Quitar en lote';

  @override
  String playlistBatchRemoveConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Quitar $count canciones de esta lista?',
      one: '¿Quitar 1 canción de esta lista?',
    );
    return '$_temp0';
  }

  @override
  String playlistRemovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se quitaron $count canciones',
      one: 'Se quitó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get playlistRemoveFailed => 'No se pudo quitar';

  @override
  String get playlistEditCover => 'Cambiar portada';

  @override
  String get playlistEditPlaylist => 'Editar lista de reproducción';

  @override
  String get playlistEditAction => 'Editar';

  @override
  String get playlistDelete => 'Eliminar lista de reproducción';

  @override
  String get playlistEmptySongs => 'No hay canciones en esta lista';

  @override
  String get playlistEmptySongsSubtitle => 'Añade música que te guste';

  @override
  String get playlistLabelBuiltIn => 'Integrada';

  @override
  String get playlistLabelAutoCreated => 'Creada automáticamente';

  @override
  String get playlistLabelAuto => 'Automática';

  @override
  String get playlistLabelHidden => 'Oculta';

  @override
  String get playlistLabelPinned => 'Fijada';

  @override
  String get playlistLabelRemote => 'Remota';

  @override
  String get playlistConfirmDelete => 'Confirmar eliminación';

  @override
  String playlistDeleteConfirm(String name) {
    return '¿Eliminar la lista \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get playlistDeleted => 'Lista de reproducción eliminada';

  @override
  String get playlistDeleteWithSongs =>
      'Eliminar también las canciones de la biblioteca (incluidos los archivos locales)';

  @override
  String get playlistEmpty => 'La lista está vacía';

  @override
  String get playlistPlayFailed => 'Error de reproducción';

  @override
  String playlistPlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reproduciendo las $count canciones',
      one: 'Reproduciendo 1 canción',
    );
    return '$_temp0';
  }

  @override
  String playlistPlayingSong(String title) {
    return 'Reproduciendo: $title';
  }

  @override
  String get playlistRemoveSongTitle => 'Quitar canción';

  @override
  String playlistRemoveSongConfirm(String title) {
    return '¿Quitar \"$title\" de esta lista de reproducción?';
  }

  @override
  String get playlistSongRemoved => 'Canción quitada';

  @override
  String get playlistDeleteSong => 'Eliminar canción';

  @override
  String playlistDeleteSongConfirm(String title) {
    return '¿Eliminar \"$title\" de la biblioteca?';
  }

  @override
  String get playlistSongDeleted => 'Canción eliminada';

  @override
  String get playlistDeleteFailed => 'No se pudo eliminar';

  @override
  String get playlistBatchDelete => 'Eliminar en lote';

  @override
  String playlistBatchDeleteSongsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar las $count canciones seleccionadas de la biblioteca?',
      one: '¿Eliminar la canción seleccionada de la biblioteca?',
    );
    return '$_temp0';
  }

  @override
  String playlistDeletedSongsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminaron $count canciones',
      one: 'Se eliminó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get playlistUnknownArtist => 'Artista desconocido';

  @override
  String playlistPickImageFailed(String error) {
    return 'No se pudo elegir la imagen: $error';
  }

  @override
  String get playlistNameRequired =>
      'Introduce un nombre para la lista de reproducción';

  @override
  String get playlistNameHint =>
      'Introduce un nombre para la lista de reproducción';

  @override
  String get playlistDescLabel => 'Descripción de la lista';

  @override
  String get playlistDescHint => 'Introduce una descripción (opcional)';

  @override
  String get playlistCoverUploadFailed => 'No se pudo subir la portada';

  @override
  String playlistSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get playlistUploadImage => 'Subir imagen';

  @override
  String get playlistPickFromSongs => 'Elegir de las canciones';

  @override
  String get playlistClear => 'Borrar';

  @override
  String get playlistSave => 'Guardar';

  @override
  String get playlistOk => 'Aceptar';

  @override
  String get playlistTitle => 'Listas de reproducción';

  @override
  String get playlistSwitchToListView => 'Cambiar a vista de lista';

  @override
  String get playlistSwitchToGridView => 'Cambiar a vista de cuadrícula';

  @override
  String get playlistCreate => 'Crear lista de reproducción';

  @override
  String get playlistCreated => 'Lista de reproducción creada';

  @override
  String get playlistUpdated => 'Lista de reproducción actualizada';

  @override
  String get playlistShowHidden => 'Mostrar listas ocultas';

  @override
  String get playlistHideHidden => 'Ocultar listas ocultas';

  @override
  String get playlistEmptyHint =>
      'Toca el botón de la esquina superior derecha para crear una lista';

  @override
  String get playlistConfirmBatchDelete => 'Confirmar eliminación en lote';

  @override
  String playlistBatchDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Eliminar las $count listas seleccionadas? Esta acción no se puede deshacer.',
      one: '¿Eliminar la lista seleccionada? Esta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String playlistDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminaron $count listas',
      one: 'Se eliminó 1 lista',
    );
    return '$_temp0';
  }

  @override
  String get playlistHidden => 'Lista oculta';

  @override
  String get playlistUnhidden => 'Lista visible de nuevo';

  @override
  String get playlistPin => 'Fijar lista';

  @override
  String get playlistUnpin => 'Desfijar';

  @override
  String get playlistPinned => 'Lista fijada';

  @override
  String get playlistUnpinned => 'Lista desfijada';

  @override
  String playlistPlayingMultiple(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reproduciendo $count listas',
      one: 'Reproduciendo 1 lista',
    );
    return '$_temp0';
  }

  @override
  String get playlistExitMultiSelect => 'Salir de la selección';

  @override
  String playlistSelectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String playlistPlayCount(int count) {
    return 'Reproducir ($count)';
  }

  @override
  String playlistDeleteCount(int count) {
    return 'Eliminar ($count)';
  }

  @override
  String get playlistTypeNormalOption => 'Lista normal';

  @override
  String get playlistTypeRadioOption => 'Lista de radio';

  @override
  String get playlistMoreActions => 'Más acciones';

  @override
  String get playlistHide => 'Ocultar lista';

  @override
  String get playlistUnhide => 'Mostrar lista';

  @override
  String get playlistPickCoverTitle => 'Elegir portada de canción';

  @override
  String get playlistClose => 'Cerrar';

  @override
  String get playlistNoCoveredSongs =>
      'No hay canciones con portada en esta lista';

  @override
  String get playlistLoadRetry => 'No se pudo cargar, toca para reintentar';

  @override
  String get playlistNoCoverLoadMore =>
      'No hay portadas en esta página, cargar más';

  @override
  String get playlistAllLoadedSimple => '— Todo cargado —';

  @override
  String get playlistSelectThisCover => 'Seleccionar esta portada';

  @override
  String get playlistErrRequestFailed => 'La solicitud falló';

  @override
  String get playlistErrTimeout => 'Se agotó el tiempo de conexión de red';

  @override
  String get playlistErrCancelled => 'Solicitud cancelada';

  @override
  String playlistErrNetwork(String message) {
    return 'Error de red: $message';
  }

  @override
  String settingsCacheSaveConfigFailed(String error) {
    return 'No se pudo guardar la configuración: $error';
  }

  @override
  String get settingsCacheCleanServerTitle => 'Vaciar caché del servidor';

  @override
  String get settingsCacheCleanServerContent =>
      '¿Vaciar toda la caché de música del servidor? Los archivos se tendrán que descargar de nuevo.';

  @override
  String get settingsCacheServerCleaned => 'Caché del servidor vaciada';

  @override
  String settingsCacheCleanFailed(String error) {
    return 'Error al vaciar: $error';
  }

  @override
  String get settingsCacheCleanLocalTitle => 'Vaciar caché local';

  @override
  String get settingsCacheCleanLocalContent =>
      '¿Vaciar toda la caché local? Incluye la caché de audio, imágenes y letras.';

  @override
  String get settingsCacheLocalCleaned => 'Caché local vaciada';

  @override
  String get settingsCacheCleanBrowserTitle => 'Vaciar caché del navegador';

  @override
  String get settingsCacheCleanBrowserContent =>
      'Esto vaciará todos los recursos de frontend en caché y recargará la página. Tu sesión y los datos del servidor no se verán afectados.';

  @override
  String get webUpdateAvailableTitle => 'Actualización disponible';

  @override
  String get webUpdateAvailableContent =>
      'El servidor se ha actualizado, pero esta página sigue ejecutando una versión anterior. Toca \"Actualizar ahora\" para vaciar la caché del navegador y cargar la última versión. Tu sesión no se verá afectada.';

  @override
  String get webUpdateAvailableRefresh => 'Actualizar ahora';

  @override
  String get webUpdateAvailableLater => 'Más tarde';

  @override
  String settingsCacheUpdateConfigFailed(String error) {
    return 'No se pudo actualizar la configuración: $error';
  }

  @override
  String get settingsCacheDirRestored =>
      'Directorio de caché predeterminado restaurado';

  @override
  String get settingsCacheDirUpdated => 'Directorio de caché actualizado';

  @override
  String settingsCacheUpdateFailed(String error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get settingsCacheConfirmClean => 'Confirmar';

  @override
  String get settingsCacheServerTitle => 'Caché de música del servidor';

  @override
  String get settingsCacheManage => 'Administrar';

  @override
  String settingsCacheNoLimit(String size) {
    return '$size (sin límite)';
  }

  @override
  String settingsCacheFileCount(int count) {
    return '$count archivos';
  }

  @override
  String get settingsCacheStatsLoadFailed =>
      'No se pudo cargar la información de la caché';

  @override
  String get settingsCacheDirTitle => 'Directorio de caché';

  @override
  String get settingsCacheNotConfigured => 'Sin configurar';

  @override
  String settingsCacheMaxSize(String size) {
    return 'Tamaño máximo de caché: $size';
  }

  @override
  String get settingsCacheTranscodeTitle =>
      'Formato de transcodificación de caché';

  @override
  String get settingsCacheTranscodeDesc =>
      'Transcodifica las canciones de red a un formato unificado al almacenarlas en caché, mejorando la compatibilidad con los dispositivos (p. ej., los altavoces Xiao AI no pueden reproducir MKV); al activarlo, el contenido de video se guarda solo en audio y la transmisión no tendrá imagen';

  @override
  String get settingsCacheTranscodeOriginal => 'Original (sin transcodificar)';

  @override
  String get settingsCacheTranscodeDialogTitle =>
      'Formato de transcodificación de caché';

  @override
  String get settingsCacheTranscodeQualityTitle =>
      'Calidad de transcodificación';

  @override
  String get settingsCacheTranscodeQualityHighest => 'Máxima calidad';

  @override
  String get settingsCacheTranscodeQualityDialogTitle =>
      'Calidad de transcodificación';

  @override
  String get settingsCacheTranscodeUpdated =>
      'Ajustes de transcodificación de caché actualizados';

  @override
  String get settingsCacheCleaning => 'Vaciando...';

  @override
  String get settingsCacheCleanServerButton => 'Vaciar caché del servidor';

  @override
  String get settingsCacheLocalTitle => 'Caché local';

  @override
  String get settingsCacheSize => 'Tamaño de caché';

  @override
  String get settingsCacheCalculating => 'Calculando...';

  @override
  String get settingsCacheLocalDesc =>
      'Incluye la caché de audio, imágenes y letras';

  @override
  String settingsCacheMaxLocalSize(String size) {
    return 'Tamaño máximo de caché local: $size';
  }

  @override
  String get settingsCacheCleanLocalButton => 'Vaciar caché local';

  @override
  String get settingsCacheBrowserTitle => 'Caché del navegador';

  @override
  String get settingsCacheBrowserDesc =>
      'Vacía los recursos de frontend en caché del navegador para solucionar problemas de página tras una actualización';

  @override
  String get settingsCacheCleanBrowserButton => 'Vaciar caché del navegador';

  @override
  String get settingsCacheDirDialogDesc =>
      'Establece el directorio de almacenamiento de la caché de música del servidor. Déjalo vacío para usar el predeterminado. Cambiar de directorio no migra los archivos de caché existentes.';

  @override
  String get settingsCacheDirLabel => 'Directorio de caché (ruta absoluta)';

  @override
  String settingsCacheDirDefault(String dir) {
    return 'Predeterminado: $dir';
  }

  @override
  String get settingsCacheValidate => 'Validar';

  @override
  String get settingsCacheRestoreDefault => 'Restaurar predeterminado';

  @override
  String get settingsCacheSave => 'Guardar';

  @override
  String get settingsCacheDirUnavailable => 'Directorio no disponible';

  @override
  String get settingsCacheDirCreated => 'Directorio creado automáticamente';

  @override
  String settingsCacheDiskTotal(String size) {
    return 'Total $size';
  }

  @override
  String settingsCacheDiskFree(String size) {
    return 'Libre $size';
  }

  @override
  String get settingsCacheDirAvailable => 'Directorio disponible';

  @override
  String get settingsMetadataUseTagTitle =>
      'Usar etiquetas para sobrescribir el título';

  @override
  String get settingsMetadataUseTagOn =>
      'Sobrescribir los títulos con las etiquetas de audio al actualizar los metadatos de canciones remotas';

  @override
  String get settingsMetadataUseTagOff =>
      'Mantener los nombres de archivo como títulos de canciones remotas, sin sobrescribir con etiquetas';

  @override
  String get settingsMetadataSaved => 'Guardado';

  @override
  String settingsMetadataSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsMetadataRefreshTitle =>
      'Actualizar metadatos de canciones remotas';

  @override
  String get settingsMetadataRefreshSubtitle =>
      'Analizar todas las canciones remotas con metadatos incompletos';

  @override
  String get settingsMetadataStart => 'Iniciar';

  @override
  String get settingsMetadataPreparing => 'Preparando...';

  @override
  String get settingsMetadataRefreshing => 'Actualizando metadatos';

  @override
  String get settingsMetadataStatusCancelled => 'Cancelado';

  @override
  String get settingsMetadataStatusFailed => 'Fallido';

  @override
  String get settingsMetadataStatusDone => 'Completado';

  @override
  String settingsMetadataSuccess(int count) {
    return '$count correctos';
  }

  @override
  String settingsMetadataFailedCount(int count) {
    return ', $count fallidos';
  }

  @override
  String settingsMetadataRefreshResult(String status) {
    return 'Actualización de metadatos $status';
  }

  @override
  String get settingsMetadataRefreshAgain => 'Actualizar de nuevo';

  @override
  String get settingsClientDownloadTitle => 'Descargar app cliente';

  @override
  String get settingsClientDownloadIntro =>
      'En comparación con la interfaz web, el cliente nativo admite reproducción en segundo plano, caché local, controles multimedia en pantalla de bloqueo/notificaciones y más.';

  @override
  String get settingsClientDownloadStandardSection =>
      'Estándar · Se conecta al servidor actual';

  @override
  String get settingsClientDownloadBundleSection =>
      'Bundle · Backend integrado, sin necesidad de servidor';

  @override
  String get settingsClientDownloadStandardAllVersions =>
      'Todas las versiones estándar';

  @override
  String get settingsClientDownloadBundleAllVersions =>
      'Todas las versiones bundle';

  @override
  String settingsClientDownloadRecommendFor(String os) {
    return 'Recomendado para tu dispositivo: $os';
  }

  @override
  String settingsClientDownloadStandardBtn(String label) {
    return 'Estándar ($label)';
  }

  @override
  String settingsClientDownloadBundleBtn(String label) {
    return 'Bundle ($label)';
  }

  @override
  String get settingsClientDownloadNoteUnsigned =>
      'Sin firmar, requiere instalación manual';

  @override
  String get settingsTabConfigTitle => 'Ajustes de menú';

  @override
  String get settingsTabConfigBuiltInSection => 'Páginas integradas';

  @override
  String get settingsTabConfigLibrary => 'Biblioteca';

  @override
  String get settingsTabConfigPlaylists => 'Listas de reproducción';

  @override
  String get settingsTabConfigPluginEntry => 'Entradas de plugins';

  @override
  String get settingsTabConfigNoPlugins => 'No hay plugins disponibles';

  @override
  String get settingsTabConfigNoPluginsHint =>
      'Primero instala y activa los plugins en los ajustes';

  @override
  String get settingsTabConfigPluginOrder => 'Orden de plugins';

  @override
  String settingsTabConfigEnabledCount(int count) {
    return '$count pestaña(s) activadas (Inicio y Ajustes siempre se muestran)';
  }

  @override
  String get settingsTabConfigCollapseHint =>
      'En móvil, las pestañas más allá de 5 se agrupan en el menú \"Más\"';

  @override
  String settingsTabConfigMaxTabs(int count) {
    return 'Mostrar como máximo $count pestañas';
  }

  @override
  String settingsTabConfigSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsUpgradeStatusStable => 'Estable';

  @override
  String get settingsUpgradeStatusDev => 'Dev';

  @override
  String get settingsUpgradeStatusDownloading => 'Descargando...';

  @override
  String get settingsUpgradeStatusTesting => 'Verificando...';

  @override
  String get settingsUpgradeStatusReplacing => 'Reemplazando...';

  @override
  String get settingsUpgradeStatusResetting => 'Revirtiendo...';

  @override
  String get settingsUpgradeStatusRestarting => 'Reiniciando...';

  @override
  String get settingsUpgradeStatusCompleted => 'Actualización completada';

  @override
  String get settingsUpgradeStatusFailed => 'Error en la actualización';

  @override
  String get settingsUpgradeStatusIdle => 'Inactivo';

  @override
  String get settingsFrontendVerDevVersion => 'Versión de desarrollo';

  @override
  String settingsFrontendVerCheckFailed(String error) {
    return 'No se pudo comprobar si hay actualizaciones del cliente: $error';
  }

  @override
  String settingsScanScanFailed(String error) {
    return 'Error al escanear: $error';
  }

  @override
  String settingsScanCancelFailed(String error) {
    return 'Error al cancelar: $error';
  }

  @override
  String get settingsScanModeSkipDesc =>
      'Solo importa los archivos de música recién descubiertos';

  @override
  String get settingsScanModeReimportDesc =>
      'Volver a escanear y sobrescribir toda la información de música';

  @override
  String get settingsScanDismiss => 'Descartar';

  @override
  String get settingsScanExcludeDirTitle => 'Ajustes de directorios excluidos';

  @override
  String get settingsScanExcludeDirSubtitle =>
      'Configura los directorios que se ignorarán durante el escaneo';

  @override
  String get settingsScanModeSkip => 'Omitir existentes';

  @override
  String get settingsScanModeReimport => 'Reimportar';

  @override
  String get settingsScanStarting => 'Iniciando...';

  @override
  String get settingsScanScanLocal => 'Escanear música local';

  @override
  String settingsScanScanSelectedDirs(int count) {
    return 'Escanear $count directorios seleccionados';
  }

  @override
  String get settingsScanTargetDirsTitle =>
      'Directorios específicos (opcional)';

  @override
  String get settingsScanTargetDirsSubtitle =>
      'Escanea solo los directorios seleccionados; déjalo vacío para escanear toda la biblioteca';

  @override
  String settingsScanTargetDirsSelected(int count) {
    return '$count directorios seleccionados';
  }

  @override
  String get settingsScanDirsToScan => 'Directorios a escanear:';

  @override
  String get settingsScanClear => 'Borrar';

  @override
  String get settingsScanCreatingPlaylists =>
      'Creando automáticamente listas por directorio...';

  @override
  String get settingsScanSplittingCue => 'Dividiendo pista única (CUE)...';

  @override
  String settingsScanSplittingCueProgress(int count) {
    return 'Dividiendo pista única (CUE): $count fuentes procesadas';
  }

  @override
  String get settingsScanDiscovering => 'Descubriendo archivos...';

  @override
  String settingsScanDiscoveringProgress(int count) {
    return 'Descubriendo archivos: $count encontrados';
  }

  @override
  String settingsScanScanningFile(String file) {
    return 'Escaneando: $file';
  }

  @override
  String settingsScanProgressStats(
    int scanned,
    int total,
    int imported,
    int skipped,
    int failed,
  ) {
    return 'Procesados: $scanned/$total, importados: $imported, omitidos: $skipped, fallidos: $failed';
  }

  @override
  String get settingsScanCancelScan => 'Cancelar escaneo';

  @override
  String get settingsScanAutoCreatePlaylists =>
      'Crear listas automáticamente tras el escaneo';

  @override
  String get settingsScanAutoCreatePlaylistsDesc =>
      'Genera listas automáticamente según la estructura de directorios';

  @override
  String get settingsScanAutoFingerprint =>
      'Calcular huellas de audio tras el escaneo';

  @override
  String get settingsScanAutoFingerprintDesc =>
      'Las huellas solo se usan para detectar duplicados y búsquedas de plugins. Activarlo en una biblioteca grande mantiene la CPU ocupada mucho tiempo; si está desactivado, puedes calcularlas manualmente en la página de detección de duplicados';

  @override
  String get settingsScanLoadingConfig => 'Cargando...';

  @override
  String get settingsScanReadConfigFailed => 'No se pudo leer la configuración';

  @override
  String settingsScanSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsScanPlaylistModeDirectory => 'Por carpeta';

  @override
  String get settingsScanPlaylistModeDirectoryDesc =>
      'Genera una lista separada para cada carpeta';

  @override
  String get settingsScanPlaylistModeTopLevel =>
      'Por carpeta de nivel superior';

  @override
  String get settingsScanPlaylistModeTopLevelDesc =>
      'Fusiona las canciones de las subcarpetas en la lista de la carpeta de nivel superior';

  @override
  String get settingsScanPlaylistModeBubbleUp => 'Incluir subdirectorios';

  @override
  String get settingsScanPlaylistModeBubbleUpDesc =>
      'Las canciones aparecen en todas las listas de las carpetas superiores';

  @override
  String get settingsScanPlaylistModeTitle => 'Modo de creación de listas';

  @override
  String get settingsScanPlaylistModeDisabled =>
      'La creación automática de listas está desactivada; esta opción no tiene efecto';

  @override
  String get settingsScanTitleSource => 'Usar el nombre de archivo como título';

  @override
  String get settingsScanTitleSourceFilenameDesc =>
      'Usa el nombre de archivo (sin extensión) como título de la canción; adecuado cuando los nombres ya están numerados';

  @override
  String get settingsScanTitleSourceTagDesc =>
      'Prefiere la información de etiquetas de audio para el título de la canción';

  @override
  String get settingsScanTitleSourceSaved =>
      'Guardado; surte efecto tras escanear en modo \'Reimportar\'';

  @override
  String get settingsScanInterval10Min => '10 minutos';

  @override
  String get settingsScanInterval30Min => '30 minutos';

  @override
  String get settingsScanInterval1Hour => '1 hora';

  @override
  String get settingsScanInterval3Hour => '3 horas';

  @override
  String get settingsScanInterval6Hour => '6 horas';

  @override
  String get settingsScanInterval12Hour => '12 horas';

  @override
  String get settingsScanInterval24Hour => '24 horas';

  @override
  String settingsScanIntervalSeconds(int count) {
    return '$count segundos';
  }

  @override
  String get settingsScanAutoScan => 'Escaneo automático';

  @override
  String settingsScanAutoScanInterval(String interval) {
    return 'Escaneo automático cada $interval';
  }

  @override
  String get settingsScanAutoScanOff => 'Desactivado';

  @override
  String get settingsScanScanInterval => 'Intervalo de escaneo';

  @override
  String settingsScanCompletedSummary(int count) {
    return 'Escaneo completado, $count canciones locales en total';
  }

  @override
  String settingsScanCompletedStats(int imported, int skipped, int failed) {
    return 'Importados $imported, omitidos $skipped, fallidos $failed';
  }

  @override
  String get settingsScanRescan => 'Volver a escanear';

  @override
  String settingsScanCancelledSummary(int count) {
    return 'Escaneo cancelado ($count archivos procesados)';
  }

  @override
  String get settingsScanErrorTitle => 'Error de escaneo';

  @override
  String settingsExcludeDirLoadFailed(String error) {
    return 'No se pudo cargar la configuración: $error';
  }

  @override
  String get settingsExcludeDirSaved =>
      'Ajustes de directorios excluidos guardados; limpiando en segundo plano las canciones de los directorios excluidos';

  @override
  String settingsExcludeDirSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsExcludeDirTabName => 'Por nombre';

  @override
  String get settingsExcludeDirTabPath => 'Por ruta';

  @override
  String get settingsExcludeDirTabPlaylist => 'Exclusión en listas';

  @override
  String get settingsExcludeDirSaving => 'Guardando...';

  @override
  String get settingsExcludeDirSaveConfig => 'Guardar ajustes de exclusión';

  @override
  String get settingsExcludeDirSaveHint =>
      'Tras guardar, las canciones importadas en directorios excluidos se limpiarán automáticamente';

  @override
  String get settingsExcludeDirInputName =>
      'Introduce el nombre del directorio';

  @override
  String get settingsExcludeDirInputHint =>
      'Escribe y selecciona, o pulsa Enter para añadir';

  @override
  String get settingsExcludeDirLoadingCandidates => 'Cargando candidatos...';

  @override
  String get settingsExcludeDirAdd => 'Añadir';

  @override
  String get settingsExcludeDirExcludedNames =>
      'Nombres de directorio excluidos:';

  @override
  String get settingsExcludeDirNameHint =>
      'Se excluirá cualquier directorio que contenga este nombre en cualquier nivel de ruta';

  @override
  String settingsExcludeDirMusicDir(String path) {
    return 'Directorio de música: $path';
  }

  @override
  String get settingsExcludeDirExcludedPaths => 'Rutas excluidas:';

  @override
  String get settingsExcludeDirAutoCreateExcluded =>
      'Directorios excluidos de las listas creadas automáticamente:';

  @override
  String get settingsExcludeDirAutoCreateHint =>
      'Los directorios que contengan este nombre en cualquier nivel no se crearán automáticamente como listas';

  @override
  String get settingsServersTitle => 'Servidores';

  @override
  String get settingsServersTestAll => 'Probar todos';

  @override
  String get settingsServersEmptyTitle => 'Aún no hay servidores añadidos';

  @override
  String get settingsServersEmptyHint =>
      'Toca el botón \"+\" para añadir una dirección de API.\nAl iniciar, los servidores se comprueban en orden y se usa el primero que responde.';

  @override
  String get settingsServersAdd => 'Añadir servidor';

  @override
  String get settingsServersEditTitle => 'Editar servidor';

  @override
  String get settingsServersNameLabel => 'Nombre (opcional)';

  @override
  String get settingsServersNameHint => 'LAN / WAN / Respaldo';

  @override
  String get settingsServersUrlLabel => 'Dirección de la API';

  @override
  String get settingsServersUsername => 'Nombre de usuario';

  @override
  String get settingsServersPassword => 'Contraseña';

  @override
  String get settingsServersSave => 'Guardar';

  @override
  String settingsServersSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsServersDeleteTitle => 'Eliminar servidor';

  @override
  String get settingsServersDeleteCurrentConfirm =>
      'Este es el servidor en uso. Tras eliminarlo, los servidores restantes de la lista se volverán a probar en el próximo inicio. ¿Continuar?';

  @override
  String settingsServersDeleteConfirm(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String settingsServersReachable(String name) {
    return '$name es accesible';
  }

  @override
  String settingsServersUnreachable(String name) {
    return '$name no es accesible';
  }

  @override
  String settingsServersProbeResult(int ok, int total) {
    return 'Prueba completada: $ok / $total accesibles';
  }

  @override
  String get settingsServersAlreadyCurrent => 'Ya es el servidor actual';

  @override
  String settingsServersSwitched(String name) {
    return 'Cambiado a $name, inicia sesión de nuevo';
  }

  @override
  String get settingsServersSwitchTo => 'Cambiar a este';

  @override
  String get settingsServersTestConnection => 'Probar conexión';

  @override
  String get settingsServersEditAction => 'Editar';

  @override
  String get settingsServersLocalMode => 'Modo local';

  @override
  String get settingsServersLocalModeDesc =>
      'Al activarlo, el backend se ejecuta en este dispositivo para que puedas reproducir música local sin red.';

  @override
  String get settingsServersMusicDir => 'Carpeta de música';

  @override
  String get settingsServersNotSelected => 'Sin seleccionar';

  @override
  String get settingsServersSelect => 'Seleccionar';

  @override
  String get settingsServersFixedMusicDirHint =>
      'Coloca la música en la carpeta de Songloft mediante la app Archivos o una computadora (Finder / uso compartido de archivos de iTunes) y vuelve a escanear.';

  @override
  String settingsServersSwitchFailed(String error) {
    return 'Error al cambiar: $error';
  }

  @override
  String get settingsServersSwitchedLocal => 'Cambiado a modo local';

  @override
  String get settingsServersMusicDirUpdated => 'Carpeta de música actualizada';

  @override
  String get settingsDuplicateTitle => 'Detección de duplicados';

  @override
  String get settingsDuplicateDismissError => 'Descartar';

  @override
  String get settingsDuplicateIntro =>
      'Identifica archivos duplicados con contenido idéntico mediante huellas de audio. La misma canción se reconoce incluso con distintos nombres de archivo y formatos.';

  @override
  String get settingsDuplicateFingerprintStats => 'Estadísticas de huellas';

  @override
  String get settingsDuplicateLocalSongs => 'Canciones locales';

  @override
  String get settingsDuplicateComputed => 'Con huella';

  @override
  String get settingsDuplicatePending => 'Pendientes';

  @override
  String get settingsDuplicateUncomputable => 'No calculables';

  @override
  String get settingsDuplicateUncomputableHint =>
      'Estos archivos no tienen pista de audio, están dañados, agotaron el tiempo o el ffmpeg del servidor no admite su formato. No se reintentarán automáticamente: usa \"Reintentar solo fallidos\" (p. ej. tras una actualización del servidor) o \"Recalcular todas las huellas\".';

  @override
  String get settingsDuplicateViewFailed => 'Ver detalles del error';

  @override
  String get settingsDuplicateFailedTitle => 'Canciones con huella fallida';

  @override
  String get settingsDuplicateNoFailed => 'No hay canciones fallidas';

  @override
  String settingsDuplicateSongCount(int count) {
    return '$count';
  }

  @override
  String get settingsDuplicateChromaprintMissing =>
      'La detección de huellas de audio requiere ffmpeg con soporte de chromaprint. Los usuarios de Docker pueden simplemente actualizar a la última imagen.';

  @override
  String get settingsDuplicateStartCompute => 'Calcular y detectar';

  @override
  String get settingsDuplicateCheck => 'Detectar duplicados';

  @override
  String get settingsDuplicateRecomputeAll => 'Recalcular todas las huellas';

  @override
  String get settingsDuplicateRetryFailed => 'Reintentar solo fallidos';

  @override
  String settingsDuplicateComputing(int computed, int total) {
    return 'Calculando huellas de audio... $computed/$total';
  }

  @override
  String settingsDuplicateFailed(int count) {
    return 'Fallidos: $count';
  }

  @override
  String get settingsDuplicateAutoDetect =>
      'Los duplicados se detectarán automáticamente al terminar el cálculo';

  @override
  String get settingsDuplicateStopCompute => 'Detener cálculo';

  @override
  String get settingsDuplicateStopComputeHint =>
      'Las huellas ya calculadas se conservan; las canciones restantes se calcularán la próxima vez';

  @override
  String get settingsDuplicateRecheck => 'Volver a comprobar';

  @override
  String get settingsDuplicateNoResults =>
      'No se encontraron canciones duplicadas';

  @override
  String get settingsDuplicateNoResultsHint =>
      '¡Tu biblioteca de música está limpia!';

  @override
  String settingsDuplicateSummary(int groups, int songs) {
    return 'Se encontraron $groups grupos duplicados ($songs canciones en total)';
  }

  @override
  String settingsDuplicateIgnoredCount(int count) {
    return '$count grupos ignorados';
  }

  @override
  String settingsDuplicateCleanAll(int count) {
    return 'Limpiar todos los duplicados (eliminar $count)';
  }

  @override
  String settingsDuplicateGroupLabel(int index) {
    return 'Grupo duplicado $index';
  }

  @override
  String get settingsDuplicateUnignore => 'Dejar de ignorar';

  @override
  String get settingsDuplicateIgnore => 'Ignorar este grupo';

  @override
  String get settingsDuplicateDeleteUnselected => 'Eliminar no seleccionadas';

  @override
  String get settingsDuplicateRecommended => 'Recomendado';

  @override
  String get settingsDuplicateConfirmTitle => 'Confirmar eliminación';

  @override
  String settingsDuplicateConfirmMessage(int count) {
    return 'Esto eliminará $count canciones duplicadas y sus archivos de audio, conservando la versión seleccionada de cada grupo. Esta acción no se puede deshacer.';
  }

  @override
  String settingsDuplicateDeleted(int count) {
    return 'Se eliminaron $count canciones duplicadas';
  }

  @override
  String settingsDuplicateDeleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get settingsCategoryAppearanceTitle => 'Apariencia';

  @override
  String get settingsCategoryAppearanceSubtitle => 'Tema, menú y pantalla';

  @override
  String get settingsCategoryPlaybackTitle => 'Reproducción';

  @override
  String get settingsCategoryPlaybackSubtitle => 'Calidad de audio';

  @override
  String get settingsCategoryLibraryTitle => 'Biblioteca';

  @override
  String get settingsCategoryLibrarySubtitle =>
      'Escaneo, importación y conversión';

  @override
  String get settingsCategoryExtensionsTitle => 'Extensiones';

  @override
  String get settingsCategoryExtensionsSubtitle => 'Gestión de plugins';

  @override
  String get settingsCategoryCacheTitle => 'Caché';

  @override
  String get settingsCategoryCacheSubtitle => 'Caché del servidor y local';

  @override
  String get settingsCategoryNetworkTitle => 'Red';

  @override
  String get settingsCategoryNetworkSubtitle => 'Configuración de proxy';

  @override
  String get settingsCategoryDataTitle => 'Datos';

  @override
  String get settingsCategoryDataSubtitle =>
      'Exportación e importación de listas';

  @override
  String get settingsCategoryAboutTitle => 'Acerca de y actualizaciones';

  @override
  String get settingsCategoryAboutSubtitle => 'Versión y registros';

  @override
  String get settingsCategoryAccountTitle => 'Cuenta';

  @override
  String get settingsCategoryAccountSubtitle => 'Servidor e inicio de sesión';

  @override
  String get settingsDevVersion => 'Compilación de desarrollo';

  @override
  String get settingsStableVersion => 'Estable';

  @override
  String get settingsLocalMode => 'Modo local';

  @override
  String get settingsManage => 'Administrar';

  @override
  String get settingsMenuTitle => 'Ajustes de menú';

  @override
  String get settingsMenuLibrary => 'Biblioteca';

  @override
  String get settingsMenuPlaylists => 'Listas de reproducción';

  @override
  String settingsTabsEnabledCount(int count) {
    return '$count pestañas activadas (Inicio y Ajustes siempre se muestran)';
  }

  @override
  String get settingsTabsCollapseHint =>
      'En móvil, las pestañas más allá de 5 se agrupan en el menú \"Más\"';

  @override
  String settingsMaxTabsLimit(int count) {
    return 'Puedes mostrar como máximo $count pestañas';
  }

  @override
  String settingsSaveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get settingsQualityOriginal => 'Calidad original';

  @override
  String get settingsQualityLow => 'Baja (128 kbps)';

  @override
  String get settingsQualityMedium => 'Media (192 kbps)';

  @override
  String get settingsQualityHigh => 'Alta (320 kbps)';

  @override
  String get settingsQualityTitle => 'Calidad de audio';

  @override
  String get settingsQualityDialogTitle => 'Seleccionar calidad de audio';

  @override
  String get settingsQualityOriginalDesc =>
      'Sin transcodificación, usa la calidad original del archivo';

  @override
  String get settingsQualityTranscodeDesc =>
      'Transcodificar a MP3, adecuado para redes débiles';

  @override
  String get settingsAutoPlayOnLaunchTitle =>
      'Reproducción automática al iniciar';

  @override
  String get settingsAutoPlayOnLaunchDesc =>
      'Reanuda automáticamente la última reproducción al abrir la app';

  @override
  String get settingsMiniPlayerControlsTitle => 'Botones del mini reproductor';

  @override
  String get settingsMiniPlayerControlsDesc =>
      'Qué controles mostrar en la barra del mini reproductor inferior';

  @override
  String get settingsMiniPlayerControlsDialogTitle => 'Botones a mostrar';

  @override
  String get settingsMiniPlayerControlsPlayOnly => 'Solo reproducir/pausar';

  @override
  String get settingsMiniPlayerControlsPrevNext => 'Anterior / siguiente';

  @override
  String get settingsMiniPlayerControlsPrevNextMode =>
      'Anterior / siguiente + modo de reproducción';

  @override
  String get settingsHomeGridTitle => 'Cuadrícula de inicio de listas';

  @override
  String get settingsHomeGridDesc =>
      'Columnas y filas de las secciones \"Mis listas\" / \"Mis radios\" en la página de inicio de pantalla ancha';

  @override
  String get settingsHomeGridColumnsTitle => 'Por fila';

  @override
  String get settingsHomeGridColumnsAuto => 'Automático';

  @override
  String get settingsHomeGridRowsTitle => 'Filas';

  @override
  String get settingsHomeGridRowsAll => 'Todas';

  @override
  String settingsHomeGridSummary(String layout, int count) {
    return 'Actual: $layout — hasta $count listas';
  }

  @override
  String settingsHomeGridSummaryAuto(String layout) {
    return 'Actual: $layout — las columnas se adaptan al ancho de la ventana (3 en tablet, 4 en escritorio)';
  }

  @override
  String settingsHomeGridSummaryAllRows(String layout, int count) {
    return 'Actual: $layout — muestra todas las listas (hasta $count por sección; usa \"Ver todo\" para el resto)';
  }

  @override
  String get settingsHomeGridClampHint =>
      'Las columnas se reducen automáticamente cuando la ventana es demasiado estrecha para mantener legibles las tarjetas.';

  @override
  String get settingsHomeGridNarrowHint =>
      'Esta ventana es estrecha, por lo que las listas del inicio usan un carrusel horizontal; el ajuste se aplica cuando la ventana sea más ancha.';

  @override
  String get settingsFontScaleTitle => 'Tamaño de fuente';

  @override
  String get settingsFontScaleSmall => 'Pequeña';

  @override
  String get settingsFontScaleDefault => 'Predeterminada';

  @override
  String get settingsFontScaleLarge => 'Grande';

  @override
  String get settingsFontScaleExtraLarge => 'XL';

  @override
  String get settingsAutoEnterLyricsOnLaunchTitle => 'Abrir letras al iniciar';

  @override
  String get settingsAutoEnterLyricsOnLaunchDesc =>
      'Abre automáticamente la vista de letras a pantalla completa al abrir la app (se adapta al tamaño de pantalla)';

  @override
  String get settingsNotificationLyricInTitleTitle =>
      'Letras en el título de la notificación';

  @override
  String get settingsNotificationLyricInTitleDesc =>
      'Activado: la línea de título muestra las letras y el nombre de la canción pasa al subtítulo. Desactivado: el título muestra el nombre de la canción y las letras van al subtítulo';

  @override
  String get settingsDesktopLyricTitle => 'Letras en escritorio';

  @override
  String get settingsDesktopLyricDesc =>
      'Muestra una ventana flotante de letras en el escritorio que se desplaza con la reproducción';

  @override
  String get settingsDesktopLyricLockTitle => 'Bloquear posición de las letras';

  @override
  String get settingsDesktopLyricLockDesc =>
      'Al bloquear, la ventana no se puede arrastrar y los clics atraviesan hacia lo que hay debajo';

  @override
  String get settingsDesktopLyricFontSizeTitle =>
      'Tamaño de fuente de las letras';

  @override
  String get settingsDesktopLyricFontSizeSmall => 'Pequeña';

  @override
  String get settingsDesktopLyricFontSizeMedium => 'Mediana';

  @override
  String get settingsDesktopLyricFontSizeLarge => 'Grande';

  @override
  String get settingsDesktopLyricOpacityTitle => 'Opacidad del fondo';

  @override
  String get desktopLyricNoLyric => 'No hay letras disponibles';

  @override
  String get desktopLyricContextLock => 'Bloquear posición';

  @override
  String get desktopLyricContextHide => 'Ocultar letras de escritorio';

  @override
  String get settingsShortcutsEntryTitle => 'Atajos de teclado';

  @override
  String get settingsShortcutsEntrySubtitle =>
      'Personaliza las teclas de control de reproducción';

  @override
  String get settingsShortcutsPageTitle => 'Atajos de teclado';

  @override
  String get settingsShortcutsEnableTitle => 'Activar atajos de teclado';

  @override
  String get settingsShortcutsEnableSubtitle =>
      'Controla la reproducción con atajos dentro de la ventana de escritorio';

  @override
  String get settingsShortcutActionPlayPause => 'Reproducir / Pausar';

  @override
  String get settingsShortcutActionPlayNext => 'Siguiente pista';

  @override
  String get settingsShortcutActionPlayPrev => 'Pista anterior';

  @override
  String get settingsShortcutActionSeekForward => 'Avanzar';

  @override
  String get settingsShortcutActionSeekBackward => 'Retroceder';

  @override
  String get settingsShortcutActionVolumeUp => 'Subir volumen';

  @override
  String get settingsShortcutActionVolumeDown => 'Bajar volumen';

  @override
  String get settingsShortcutActionToggleMute => 'Silenciar / reactivar';

  @override
  String get settingsShortcutRecordPrompt => 'Pulsa una combinación de teclas…';

  @override
  String get settingsShortcutUnset => 'Sin asignar';

  @override
  String get settingsShortcutConflictTitle => 'Conflicto de atajos';

  @override
  String settingsShortcutConflict(String action) {
    return 'Esta combinación ya la usa \"$action\"';
  }

  @override
  String get settingsShortcutOverride => 'Sobrescribir';

  @override
  String get settingsShortcutClear => 'Borrar';

  @override
  String get settingsShortcutResetAll =>
      'Restablecer todo a los valores predeterminados';

  @override
  String get settingsShortcutResetAllConfirm =>
      '¿Restablecer todos los atajos a sus valores predeterminados?';

  @override
  String settingsQualitySwitched(String quality) {
    return 'Calidad de audio cambiada a $quality';
  }

  @override
  String settingsSwitchFailed(String error) {
    return 'Error al cambiar: $error';
  }

  @override
  String get settingsLibraryDuplicateTitle => 'Detección de duplicados';

  @override
  String get settingsLibraryDuplicateSubtitle =>
      'Identifica archivos duplicados con contenido idéntico mediante huella de audio';

  @override
  String get settingsPluginStoreTitle => 'Tienda de plugins';

  @override
  String get settingsPluginStoreSubtitle => 'Explora e instala plugins';

  @override
  String get settingsExportPlaylistTitle => 'Exportar listas de reproducción';

  @override
  String get settingsExportPlaylistSubtitle =>
      'Respalda todos los datos de las listas en un archivo JSON';

  @override
  String get settingsImportPlaylistTitle => 'Importar listas de reproducción';

  @override
  String get settingsImportPlaylistSubtitle =>
      'Restaura los datos de las listas desde un archivo JSON de respaldo';

  @override
  String get settingsDownloadAppTitle => 'Descargar la app';

  @override
  String get settingsDownloadAppSubtitle =>
      'Consigue el cliente nativo móvil / de escritorio con reproducción en segundo plano, caché y más';

  @override
  String get settingsWebDebugConsoleTitle => 'Consola de depuración';

  @override
  String get settingsWebDebugConsoleSubtitle =>
      'Activa el panel de depuración web de NextConsole (requiere recargar la página)';

  @override
  String get settingsWebDebugConsoleEnabled =>
      'Consola de depuración activada, la página se recargará';

  @override
  String get settingsWebDebugConsoleDisabled =>
      'Consola de depuración desactivada, la página se recargará';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutSubtitle => 'Información de versión y licencia';

  @override
  String get settingsAccountServer => 'Servidor';

  @override
  String get settingsNoMusicDir => 'No hay carpeta de música seleccionada';

  @override
  String get settingsLogout => 'Cerrar sesión';

  @override
  String get settingsLogoutConfirmTitle => 'Confirmar cierre de sesión';

  @override
  String get settingsLogoutConfirmContent =>
      '¿Seguro que quieres cerrar la sesión de la cuenta actual?';

  @override
  String get settingsLogoutButton => 'Cerrar sesión';

  @override
  String get settingsExportNotLoggedIn =>
      'Sin sesión iniciada, no se puede exportar';

  @override
  String settingsExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get settingsImportReadFailed =>
      'No se puede leer el contenido del archivo';

  @override
  String get settingsImportPathFailed =>
      'No se pudo obtener la ruta del archivo';

  @override
  String settingsImportComplete(
    Object created,
    Object merged,
    Object songsCreated,
    Object songsMatched,
  ) {
    return 'Importación completada: $created listas creadas, $merged fusionadas, $songsCreated canciones creadas, $songsMatched coincidentes';
  }

  @override
  String settingsImportFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get settingsCheckServerUpdate => 'Buscar actualizaciones del servidor';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Nueva versión disponible: $version';
  }

  @override
  String settingsCurrentVersionLatest(String version) {
    return 'Versión actual: $version (actualizada)';
  }

  @override
  String get settingsCheckingUpdate => 'Buscando actualizaciones...';

  @override
  String get settingsCheckUpdateFailed => 'No se pudo buscar actualizaciones';

  @override
  String get settingsCheckClientUpdate => 'Buscar actualizaciones del cliente';

  @override
  String get settingsAutoUpdateCheckTitle =>
      'Buscar actualizaciones al iniciar';

  @override
  String settingsAutoUpdateCheckSubtitle(int hours) {
    return 'Comprueba en segundo plano poco después del inicio, como máximo una vez cada $hours horas';
  }

  @override
  String settingsCurrentVersion(String version) {
    return 'Versión actual: $version';
  }

  @override
  String get settingsHlsProxyTitle => 'Proxy de backend para radio HLS';

  @override
  String get settingsHlsProxySubtitle =>
      'Al activarlo, el servidor obtiene el m3u8 de la radio y hace de proxy de los segmentos, evitando la protección antienlaces por Referer / CORS. Todos los segmentos usan el ancho de banda de esta máquina: ten en cuenta el costo de tráfico.';

  @override
  String get settingsHlsProxyEnabled => 'Proxy HLS activado';

  @override
  String get settingsHlsProxyDisabled => 'Proxy HLS desactivado';

  @override
  String get settingsVolumeNormalizeTitle => 'Normalización de volumen';

  @override
  String get settingsVolumeNormalizeSubtitle =>
      'Activa la normalización de sonoridad EBU R128 para igualar el volumen entre distintas fuentes de audio. Requiere ffmpeg; aumenta el uso de CPU y la latencia del primer arranque';

  @override
  String get settingsVolumeNormalizeEnabled =>
      'Normalización de volumen activada';

  @override
  String get settingsVolumeNormalizeDisabled =>
      'Normalización de volumen desactivada';

  @override
  String get settingsVolumeNormalizeLoudnessTitle =>
      'Sonoridad objetivo (LUFS)';

  @override
  String get settingsVolumeNormalizeLoudnessSubtitle =>
      'Personaliza la sonoridad objetivo EBU R128, predeterminada en -16. El streaming suele usar -14 y la radiodifusión -23. Rango de -40 a -5';

  @override
  String get settingsVolumeNormalizeLoudnessInvalid =>
      'Introduce un valor entre -40 y -5';

  @override
  String settingsVolumeNormalizeLoudnessSaved(String value) {
    return 'Sonoridad objetivo establecida en $value LUFS';
  }

  @override
  String get settingsProxyAllowlistTitle =>
      'Lista blanca de proxy para redes privadas';

  @override
  String get settingsProxyAllowlistEmpty =>
      'Sin configurar (las direcciones privadas se rechazan)';

  @override
  String settingsProxyAllowlistCount(int count) {
    return '$count dirección(es)/rango(s) permitidos';
  }

  @override
  String get settingsProxyAllowlistDialogDesc =>
      'El proxy a direcciones privadas está bloqueado por defecto para evitar SSRF. Si necesitas que este servidor haga de proxy de recursos internos (p. ej. un WebDAV accesible solo en la LAN), indica aquí las direcciones permitidas.';

  @override
  String get settingsProxyAllowlistLabel =>
      'Direcciones permitidas (una por línea)';

  @override
  String get settingsProxyAllowlistHelper =>
      'Una IP única (p. ej. 192.168.1.100) o rango CIDR (p. ej. 192.168.1.0/24) por línea. Solo afecta al proxy genérico de recursos.';

  @override
  String get settingsProxyAllowlistSaved =>
      'Lista blanca de proxy de redes privadas guardada';

  @override
  String get settingsInsecureTlsTitle =>
      'Ignorar verificación de certificados SSL';

  @override
  String get settingsInsecureTlsSubtitle =>
      'Actívalo al conectar con un servidor con certificado HTTPS autofirmado o no válido. Se aplica a las solicitudes de API y a la reproducción de audio.';

  @override
  String get settingsInsecureTlsEnabled =>
      'Verificación de certificados ignorada';

  @override
  String get settingsInsecureTlsDisabled =>
      'Verificación de certificados activada';

  @override
  String get settingsInsecureTlsWarnTitle => 'Seguridad reducida';

  @override
  String get settingsInsecureTlsWarnContent =>
      'Al activarlo se aceptará cualquier certificado HTTPS, lo que te expone a ataques de intermediario. Úsalo solo en intranets de confianza o con certificados autofirmados. ¿Activarlo de todos modos?';

  @override
  String get settingsHttpProxyTitle => 'Proxy HTTP';

  @override
  String get settingsHttpProxyNotConfigured => 'Sin configurar (directo)';

  @override
  String get settingsHttpProxyDialogDesc =>
      'Establece un proxy HTTP global. Todas las solicitudes salientes del backend (descargas de plugins, comprobaciones de actualizaciones, etc.) pasarán por él. Déjalo vacío para conexión directa.';

  @override
  String get settingsHttpProxyAddressLabel => 'Dirección del proxy';

  @override
  String get settingsHttpProxyHelper => 'Admite proxies HTTP/HTTPS/SOCKS5';

  @override
  String get settingsClear => 'Borrar';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get settingsHttpProxyCleared => 'Proxy HTTP eliminado';

  @override
  String settingsHttpProxySet(String proxy) {
    return 'Proxy HTTP configurado: $proxy';
  }

  @override
  String get settingsGithubProxyTitle => 'Proxy de GitHub';

  @override
  String get settingsGithubProxyDialogDesc =>
      'Compartido por la instalación/actualización de plugins, las comprobaciones de actualizaciones y las descargas del cliente. Elige un espejo si GitHub va lento en tu región.';

  @override
  String get settingsGithubProxyCustom => 'Proxy personalizado';

  @override
  String get settingsGithubProxyCustomHelper =>
      'Introduce una dirección de proxy, p. ej. https://example.com/';

  @override
  String get settingsGithubProxyCopyPrompt =>
      'Copiar mensaje para preguntar a una IA';

  @override
  String get settingsGithubProxyCopied =>
      'Copiado: pégalo en cualquier chat de IA';

  @override
  String get settingsGithubProxyCleared => 'Cambiado a conexión directa';

  @override
  String settingsGithubProxySet(String proxy) {
    return 'Proxy de GitHub configurado: $proxy';
  }

  @override
  String get settingsLogLevelDebug => 'Depuración (detallado, para depurar)';

  @override
  String get settingsLogLevelInfo => 'Información (predeterminado)';

  @override
  String get settingsLogLevelWarn => 'Advertencias';

  @override
  String get settingsLogLevelError => 'Errores (solo errores)';

  @override
  String get settingsLogLevelTitle => 'Nivel de registro';

  @override
  String get settingsLogLevelDialogTitle => 'Seleccionar nivel de registro';

  @override
  String settingsLogLevelSwitched(String level) {
    return 'Nivel de registro cambiado a $level';
  }

  @override
  String get settingsExportLogsTitle => 'Exportar registros';

  @override
  String get settingsExportLogsSubtitle =>
      'Empaqueta los registros de frontend y backend (con datos sensibles omitidos) para informes de errores';

  @override
  String get settingsExportLogsShareSubject => 'Registros de Songloft';

  @override
  String get settingsExportLogsSuccess =>
      'Registros empaquetados, elige cómo compartirlos o guardarlos';

  @override
  String get settingsExportLogsSuccessNoBackend =>
      'Registros de frontend exportados (registros de backend no disponibles)';

  @override
  String settingsExportLogsFailed(String error) {
    return 'No se pudieron exportar los registros: $error';
  }

  @override
  String get settingsAccountUrlNotConfigured =>
      'Sin configurar · Toca para añadir';

  @override
  String settingsAccountUrlSummary(int count, String label) {
    return '$count direcciones · Actual: $label';
  }

  @override
  String get settingsAccountLoading => 'Cargando...';

  @override
  String get settingsAboutDesc1 =>
      'Songloft es una app de servidor de música personal de código abierto.';

  @override
  String get settingsAboutDesc2 =>
      'Admite gestión de biblioteca local, reproducción en línea y extensiones de plugins.';

  @override
  String get settingsAboutGithubSemantics => 'Abrir la página de GitHub';

  @override
  String get settingsUpgradeCheckTimeout =>
      'La comprobación de actualizaciones agotó el tiempo. Prueba a cambiar el proxy e inténtalo de nuevo.';

  @override
  String settingsUpgradeCheckFailed(String error) {
    return 'No se pudo buscar actualizaciones: $error';
  }

  @override
  String get settingsUpgradeChannelDev => 'Compilación de desarrollo';

  @override
  String get settingsUpgradeChannelStable => 'Compilación estable';

  @override
  String settingsUpgradeVersionWithDetails(String version, String details) {
    return '$version ($details)';
  }

  @override
  String settingsUpgradeStartFailed(String error) {
    return 'No se pudo iniciar la actualización: $error';
  }

  @override
  String get settingsUpgradeConfirmReset => 'Confirmar reversión';

  @override
  String get settingsUpgradeConfirmResetContent =>
      '¿Revertir a la versión de imagen base del contenedor Docker?\n\nEl servicio se reiniciará automáticamente tras la reversión.';

  @override
  String settingsUpgradeResetFailed(String error) {
    return 'Error en la reversión: $error';
  }

  @override
  String get settingsUpgradeTitle => 'Buscar actualizaciones';

  @override
  String get settingsUpgradeChecking => 'Buscando actualizaciones...';

  @override
  String get settingsUpgradeUpToDate => 'Tienes la última versión';

  @override
  String settingsUpgradeCurrentVersion(String version) {
    return 'Versión actual: $version';
  }

  @override
  String get settingsUpgradeSelectVersion =>
      'Selecciona la versión a la que actualizar:';

  @override
  String settingsUpgradeBuildTime(String time) {
    return 'Fecha de compilación: $time';
  }

  @override
  String get settingsUpgradeReleaseNotes => 'Notas de la versión:';

  @override
  String get settingsUpgradeResetting => 'Revirtiendo...';

  @override
  String get settingsUpgradeResetButton => 'Revertir a la versión base';

  @override
  String get settingsUpgradeCompleted => 'Actualización completada';

  @override
  String get settingsUpgradeRestartSoon => 'La app se reiniciará en breve';

  @override
  String get settingsUpgradeFailed => 'Error en la actualización';

  @override
  String get settingsUpgradeClose => 'Cerrar';

  @override
  String get settingsUpgradeLater => 'Más tarde';

  @override
  String get settingsUpgradeGoDownload => 'Ir a descargar';

  @override
  String get settingsUpgradeUpgradeNow => 'Actualizar ahora';

  @override
  String get settingsUpgradeUploadButton => 'Subir actualización';

  @override
  String get settingsUpgradeUploading => 'Subiendo...';

  @override
  String settingsUpgradeUploadFailed(String error) {
    return 'Error al subir: $error';
  }

  @override
  String get settingsUpgradeUploadConfirmChannel =>
      'Confirmación de cambio de canal';

  @override
  String settingsUpgradeUploadConfirmChannelContent(
    String currentChannel,
    String uploadChannel,
    String version,
  ) {
    return 'El canal actual es $currentChannel, el archivo subido es $uploadChannel ($version). ¿Confirmar el cambio de canal y la actualización?\n\nEl servicio se reiniciará automáticamente.';
  }

  @override
  String settingsUpgradeUploadConfirmNormal(String version, String channel) {
    return '¿Confirmar la actualización a $version ($channel)?\n\nEl servicio se reiniciará automáticamente.';
  }

  @override
  String get settingsUpgradeUploadConfirm => 'Confirmar actualización';

  @override
  String get settingsFrontendUpgradeCheckTimeout =>
      'La comprobación de actualizaciones agotó el tiempo. Prueba a cambiar el proxy e inténtalo de nuevo.';

  @override
  String get settingsFrontendUpgradeTitle => 'Actualización del cliente';

  @override
  String get settingsFrontendUpgradeChecking => 'Buscando actualizaciones...';

  @override
  String get settingsFrontendUpgradeUpToDate => 'Tienes la última versión';

  @override
  String settingsFrontendUpgradeCurrentVersion(String version) {
    return 'Versión actual: $version';
  }

  @override
  String settingsFrontendUpgradeLatestVersion(String version) {
    return 'Última versión: $version';
  }

  @override
  String settingsFrontendUpgradePublishedAt(String date) {
    return 'Publicado: $date';
  }

  @override
  String get settingsFrontendUpgradeReleaseNotes => 'Notas de la versión:';

  @override
  String get settingsFrontendUpgradeClose => 'Cerrar';

  @override
  String get settingsFrontendUpgradeLater => 'Más tarde';

  @override
  String get settingsFrontendUpgradeGoDownload => 'Ir a descargar';

  @override
  String get settingsFrontendUpgradeDownloadFull =>
      'Descargar instalador completo';

  @override
  String get settingsFrontendUpgradeReinstallHint =>
      'Si la app se comporta mal tras una actualización en caliente, descarga el instalador completo y reinstala sobre él';

  @override
  String get settingsConfigTitle => 'Configuración';

  @override
  String get settingsConfigSubtitle =>
      'Administra los elementos de configuración del sistema';

  @override
  String get settingsConfigAdd => 'Añadir configuración';

  @override
  String get settingsConfigRefresh => 'Actualizar';

  @override
  String get settingsConfigEmpty => 'No hay elementos de configuración';

  @override
  String get settingsConfigEmptyHint =>
      'Toca \"Añadir configuración\" para crear un elemento nuevo';

  @override
  String get settingsConfigKeyLabel => 'Clave de configuración';

  @override
  String get settingsConfigKeyHint => 'p. ej. app.setting.name';

  @override
  String get settingsConfigKeyRequired =>
      'Introduce una clave de configuración';

  @override
  String get settingsConfigValueLabel => 'Valor de configuración';

  @override
  String get settingsConfigValueHint =>
      'Valor de configuración (admite varias líneas)';

  @override
  String get settingsConfigValueRequired =>
      'Introduce un valor de configuración';

  @override
  String get settingsConfigAddButton => 'Añadir';

  @override
  String get settingsConfigAdded => 'Configuración añadida';

  @override
  String settingsConfigAddFailed(String error) {
    return 'No se pudo añadir: $error';
  }

  @override
  String settingsConfigEditTitle(String key) {
    return 'Editar configuración: $key';
  }

  @override
  String settingsConfigKeyDisplay(String key) {
    return 'Clave de configuración: $key';
  }

  @override
  String get settingsConfigSave => 'Guardar';

  @override
  String get settingsConfigUpdated => 'Configuración actualizada';

  @override
  String settingsConfigUpdateFailed(String error) {
    return 'No se pudo actualizar: $error';
  }

  @override
  String get settingsConfigConfirmDelete => 'Confirmar eliminación';

  @override
  String settingsConfigDeleteConfirm(String key) {
    return '¿Eliminar la configuración \"$key\"?';
  }

  @override
  String get settingsConfigDeleted => 'Configuración eliminada';

  @override
  String settingsConfigDeleteFailed(String error) {
    return 'No se pudo eliminar: $error';
  }

  @override
  String get settingsConfigEdit => 'Editar';

  @override
  String get settingsTokenTitle => 'Gestión de tokens';

  @override
  String get settingsTokenSubtitle =>
      'Administra los tokens de inicio de sesión';

  @override
  String get settingsTokenEmpty => 'No hay tokens';

  @override
  String get settingsTokenConfirmRevoke => 'Confirmar revocación';

  @override
  String get settingsTokenRevokeConfirm =>
      'Revocar este token invalidará la sesión de inicio de sesión correspondiente. ¿Continuar?';

  @override
  String get settingsTokenRevoke => 'Revocar';

  @override
  String get settingsTokenRevoked => 'Token revocado';

  @override
  String settingsTokenRevokeFailed(String error) {
    return 'No se pudo revocar: $error';
  }

  @override
  String get settingsTokenStatusRevoked => 'Revocado';

  @override
  String get settingsTokenStatusExpired => 'Expirado';

  @override
  String get settingsTokenStatusActive => 'Activo';

  @override
  String settingsTokenType(String type) {
    return 'Tipo: $type';
  }

  @override
  String get settingsTokenTypeAccess => 'Token de acceso';

  @override
  String get settingsTokenTypeRefresh => 'Token de actualización';

  @override
  String settingsTokenClient(String info) {
    return 'Cliente: $info';
  }

  @override
  String settingsTokenExpiresAt(String time) {
    return 'Expira: $time';
  }

  @override
  String get coreTrayOpen => 'Abrir Songloft';

  @override
  String get coreTrayOpenLogs => 'Abrir directorio de registros';

  @override
  String get coreTrayExit => 'Salir';

  @override
  String get coreUrlEmpty => 'La URL no puede estar vacía';

  @override
  String get coreUrlInvalid =>
      'Introduce una URL válida (que incluya http:// o https://)';

  @override
  String get corePickMusicDir => 'Seleccionar carpeta de música';

  @override
  String get categoryFieldGenre => 'Género';

  @override
  String get categoryFieldArtist => 'Artista';

  @override
  String get categoryFieldAlbum => 'Álbum';

  @override
  String get categoryFieldYear => 'Año';

  @override
  String get categoryFieldDecade => 'Década';

  @override
  String get categoryFieldLanguage => 'Idioma';

  @override
  String get categoryFieldStyle => 'Estilo';

  @override
  String get categoryFieldFolder => 'Carpetas';

  @override
  String get categoryValueUnknown => 'Desconocido';

  @override
  String categoryValueYear(String value) {
    return '$value';
  }

  @override
  String categoryValueDecade(String value) {
    return '${value}s';
  }

  @override
  String get categoryBrowseTitle => 'Explorar por categoría';

  @override
  String categoryEmptyTitle(String label) {
    return 'No hay categorías de \"$label\"';
  }

  @override
  String get categoryEmptySubtitle =>
      'No hay canciones que clasificar en esta dimensión';

  @override
  String get folderBrowseEmpty => 'No se encontraron carpetas';

  @override
  String get folderBrowseNoMusicPath => 'Ruta de música no configurada';

  @override
  String categorySongCount(int count) {
    return '$count canciones';
  }

  @override
  String categorySearchHint(String label) {
    return 'Buscar $label…';
  }

  @override
  String categoryNoMatch(String label) {
    return 'No se encontró ningún $label que coincida';
  }

  @override
  String get songCacheCacheSong => 'Guardar en el dispositivo';

  @override
  String get songCacheRemove => 'Quitar de la caché';

  @override
  String get songCacheInfo => 'Información de la canción';

  @override
  String get songCacheConfirm => 'Guardar';

  @override
  String get songCacheCancel => 'Cancelar';

  @override
  String songCacheStarted(String title) {
    return 'Guardando \"$title\"';
  }

  @override
  String get songCacheDone => 'Guardada en el dispositivo';

  @override
  String get songCacheRemoved => 'Quitada de la caché';

  @override
  String get songCacheFailed => 'Error al guardar';

  @override
  String get songCacheLimitExceeded =>
      'Se alcanzó el límite de caché local; libera espacio en Ajustes primero';

  @override
  String get songCacheVideoWarnTitle => 'Guardar archivo de video';

  @override
  String get songCacheVideoWarnContent =>
      'Los archivos de video son grandes. ¿Guardarlo en el dispositivo de todos modos?';

  @override
  String get songInfoTitle => 'Información de la canción';

  @override
  String get songInfoArtist => 'Artista';

  @override
  String get songInfoAlbum => 'Álbum';

  @override
  String get songInfoFormat => 'Formato';

  @override
  String get songInfoBitRate => 'Bitrate';

  @override
  String get songInfoSampleRate => 'Frecuencia de muestreo';

  @override
  String get songInfoFileSize => 'Tamaño de archivo';

  @override
  String get songInfoType => 'Tipo';

  @override
  String get songInfoPlaybackSource => 'Fuente de reproducción';

  @override
  String get songInfoSourceLocal => 'Caché local';

  @override
  String get songInfoSourceRemote => 'Streaming';

  @override
  String get songInfoSourceUnknown => 'Sin reproducción';

  @override
  String get songInfoCachePath => 'Ubicación de la caché';

  @override
  String get songInfoQualityNote =>
      'La calidad de la caché sigue la calidad de reproducción establecida al guardar; cambiar el ajuste después no afecta a los archivos ya guardados.';

  @override
  String get songTypeLocalLabel => 'Local';

  @override
  String get songTypeRemoteLabel => 'Remota';

  @override
  String get songTypeRadioLabel => 'Radio';

  @override
  String get localSongCacheTitle => 'Caché de canciones del dispositivo';

  @override
  String localSongCacheSummary(int count, String size) {
    return '$count canciones · $size';
  }

  @override
  String get localSongCacheEmpty => 'No hay canciones guardadas manualmente';

  @override
  String get localSongCacheSingles => 'Canciones guardadas';

  @override
  String get localSongCachePlaylists => 'Listas guardadas';

  @override
  String get localSongCacheClearAll =>
      'Vaciar caché de canciones del dispositivo';

  @override
  String get localSongCacheClearAllConfirm =>
      '¿Vaciar toda la caché de canciones del dispositivo?';

  @override
  String get playlistCacheAll => 'Guardar lista en caché';

  @override
  String get playlistCacheClear => 'Vaciar caché de la lista';

  @override
  String playlistCacheProgress(int done, int total) {
    return 'Guardando lista en caché $done/$total';
  }

  @override
  String playlistCacheDone(int ok, int failed) {
    return 'Lista guardada en caché ($ok correctos, $failed fallidos)';
  }

  @override
  String get playlistCacheCleared => 'Caché de la lista vaciada';

  @override
  String get playHistory => 'Historial de reproducción';

  @override
  String playHistoryTitle(String name) {
    return 'Historial de reproducción · $name';
  }

  @override
  String get playHistoryEmpty => 'Aún no hay historial de reproducción';

  @override
  String get playHistoryEmptyHint =>
      'Las canciones que reproduzcas aquí se registran para que puedas retomar donde lo dejaste';

  @override
  String get playHistoryClear => 'Borrar historial';

  @override
  String get playHistoryClearConfirm =>
      '¿Borrar el historial de reproducción de aquí?';

  @override
  String get playHistoryCleared => 'Historial de reproducción borrado';

  @override
  String get playHistoryDeleteEntry => 'Quitar esta entrada';

  @override
  String get playHistoryOperationFailed =>
      'La operación falló, inténtalo de nuevo';

  @override
  String get playHistorySongMissing =>
      'Esta canción ya no está en la lista; el resto se ha añadido a la cola';

  @override
  String get scrollToTop => 'Volver arriba';

  @override
  String get playlistLocatePlaying => 'Localizar canción en reproducción';

  @override
  String get playlistLocateNotFound =>
      'La canción actual no está en esta lista';

  @override
  String get playlistSortShuffle => 'Aleatorio';

  @override
  String get playlistShuffled => 'Canciones en orden aleatorio';

  @override
  String get settingsLicensesTitle => 'Licencias de código abierto';

  @override
  String get settingsLicensesSubtitle =>
      'Licencia de distribución y componentes de terceros';

  @override
  String get licensesDistributionSection => 'Licencia de distribución';

  @override
  String get licensesDistributionHeadline =>
      'Los binarios de este cliente se distribuyen bajo la Licencia Pública General de GNU, versión 3 (GPL-3.0).';

  @override
  String get licensesDistributionWhy =>
      'Por qué: el cliente enlaza con el motor de renderizado WebF, que es GPL-3.0 puro sin excepción de enlace. Por lo tanto, cada instalador que distribuimos se rige en su totalidad por GPL-3.0.';

  @override
  String get licensesDistributionSource =>
      'El código fuente en sí sigue bajo la Licencia Apache 2.0. Compilarlo tú mismo con la dependencia WebF eliminada produce un binario sin código GPL, al que solo se aplica Apache-2.0.';

  @override
  String get licensesDistributionWeb =>
      'La compilación web no se ve afectada: WebF no admite Flutter Web y no se enlaza allí, por lo que el bundle web sigue rigiéndose solo por Apache-2.0.';

  @override
  String get licensesSourceSection => 'Código fuente correspondiente completo';

  @override
  String get licensesSourceHint =>
      'Tienes derecho al código fuente correspondiente completo de este software. Cada versión incluye un recurso CORRESPONDING-SOURCE.txt que indica los repositorios, la etiqueta y los SHAs exactos de commit usados en esa compilación.';

  @override
  String get licensesSourceClient => 'Código fuente del cliente';

  @override
  String get licensesSourceServer => 'Código fuente del servidor';

  @override
  String get licensesSourceWebf => 'Código fuente de WebF';

  @override
  String get licensesTextsSection => 'Textos de licencia';

  @override
  String get licensesGplTitle => 'Texto completo de GNU GPL v3.0';

  @override
  String get licensesGplSubtitle =>
      'Incluido dentro del instalador, legible sin conexión';

  @override
  String get licensesNoticeTitle => 'Avisos de terceros (NOTICE)';

  @override
  String get licensesNoticeSubtitle =>
      'Licencias y orígenes de WebF, libmpv, FFmpeg, fuentes y más';

  @override
  String get licensesFlutterTitle => 'Todas las licencias de paquetes';

  @override
  String get licensesFlutterSubtitle =>
      'Textos de licencia por paquete recopilados por Flutter';

  @override
  String licensesLoadFailed(String error) {
    return 'No se pudo cargar el texto de la licencia: $error';
  }

  @override
  String get manageTags => 'Administrar etiquetas';

  @override
  String get createTagHint => 'Introduce el nombre de la etiqueta nueva...';

  @override
  String get noTags => 'Aún no hay etiquetas';

  @override
  String get songCountUnit => 'canciones';

  @override
  String get songTags => 'Etiquetas';

  @override
  String get tagCreated => 'Etiqueta creada';

  @override
  String get tagDeleted => 'Etiqueta eliminada';

  @override
  String get tagRenamed => 'Etiqueta renombrada';

  @override
  String get renameTag => 'Renombrar etiqueta';

  @override
  String deleteTagConfirm(String name) {
    return '¿Eliminar la etiqueta \"$name\"? Las canciones de esta etiqueta no se eliminarán.';
  }

  @override
  String get licensesCopyAll => 'Copiar texto completo';

  @override
  String get licensesCopied => 'Copiado al portapapeles';

  @override
  String licensesOpenFailed(String url) {
    return 'No se pudo abrir el enlace: $url';
  }
}
