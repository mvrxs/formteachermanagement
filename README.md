# Form Teacher Management

**Tu gestor de confianza.** App de macOS para el seguimiento tutorial de un grupo de FP por parte del profesor-tutor: fichas de alumnos, registro de tutorías y necesidades educativas especiales. Datos locales, sin nube.

> ⚠️ **Estado: ALPHA.** En desarrollo activo, sin garantías de estabilidad.

## Características

- **Alumnos**: ficha completa y editable (datos personales, familia/tutores, contacto, salud), con **foto** por alumno.
  - Campos calculados: edad, fecha en que cumple 18, tipo de documento (DNI/NIE).
  - Estados de edad, autorización de comunicación, convalidaciones (inglés, experiencia laboral 50 %/25 %, asignaturas), prácticas (FCT) y emancipación, identificados con **simbología** en la lista.
- **Búsqueda** por texto libre y por campos con sintaxis `campo:valor` (p. ej. `localidad:Barcelona email:gmail`), más filtros por edad, autorización, inglés y emancipación.
- **Importación CSV** de Alexia: parser conforme a **RFC 4180** (comillas, comas internas, `""`), separador autodetectado (`,`/`;`), auto-mapeo de columnas con ajuste manual y aviso de duplicados por DNI/nombre (nunca fusiona).
- **Tutorías**: lista ordenable + **calendario mensual estilo macOS**, con **sincronización opcional con el Calendario nativo** (EventKit).
- **Necesidades educativas especiales** por alumno.
- **Ajustes**: apariencia, curso académico, opciones de sincronización de calendario.
- Interfaz con estética **Liquid Glass** de macOS 26 (glass en la capa de navegación; contenido con materiales estándar, según la guía de Apple).

## Privacidad

Todos los datos se guardan **en local** (SwiftData, sin CloudKit). Maneja información sensible de menores (DNI/NIE, alergias, necesidades educativas, situación familiar), que **nunca sale del dispositivo**. Los datos de ejemplo (`test-data/`) están excluidos del repositorio.

## Requisitos

- macOS 26 (Tahoe) o superior
- Xcode 26 o superior

## Compilar

```bash
xcodebuild -project GestionTutorial.xcodeproj -scheme GestionTutorial -destination 'platform=macOS' build
```

O abre `GestionTutorial.xcodeproj` en Xcode y ejecuta (⌘R).

## Autoría

Hecho por **MVRX Studio®**.

## Licencia

Software propietario. Todos los derechos reservados. Ver [LICENSE](LICENSE).
