# 🗄️ Base de Datos SGP (Integrador III -2026-1) — Documentación del Repositorio

> **¿Eres nuevo en el equipo o necesitas entender qué hay aquí?**
> Este documento es tu punto de partida. Todo lo que necesitas saber sobre la base de datos del proyecto está cubierto aquí.

---

## 📋 Tabla de Contenido

1. [Tecnología utilizada](#-tecnología-utilizada)
2. [Estructura del repositorio](#-estructura-del-repositorio)
   - [Módulos (modulo1 – modulo9)](#-módulos-modulo1--modulo9)
   - [Carpetas de desarrollo](#-carpetas-de-desarrollo)
   - [Raíz del proyecto](#-raíz-del-proyecto)
   - [Diccionario de datos](#-diccionario-de-datos)
3. [Documentación interactiva — Power BI](#-documentación-interactiva--power-bi)
4. [Conexión a la base de datos — Tailscale](#-conexión-a-la-base-de-datos--tailscale)
5. [Contacto y accesos](#-contacto-y-accesos)

---

## 🐘 Tecnología Utilizada

| Componente | Detalle |
|---|---|
| **Motor de base de datos** | PostgreSQL 18 |
| **Herramienta de diseño ER** | pgAdmin / pgERD (`.pgerd`) |
| **Documentación dinámica** | Microsoft Power BI |
| **VPN / Acceso remoto** | Tailscale |
| **Control de versiones** | Git |

---

## 📁 Estructura del Repositorio

```
📦 Raíz del Proyecto
├── 📂 modulo1/
├── 📂 modulo2/
├── 📂 ...
├── 📂 modulo9/
├── 📂 Procedimientos Almacenados/
├── 📂 Scripts de Insercion - Constraints/
├── 📂 Trigger/
├── 📂 dic_datos/
├── 📄 DiagramaRelacionalDB.pgerd
├── 📄 Roles_y_Accesos.xlsx
├── 📄 Nomenclatura.xlsx
├── 💾 backup_v1.backup
├── 💾 backup_v2.backup
└── 💾 backup_vN.backup   ← ⭐ Siempre usar el de mayor versión
```

---

### 🧩 Módulos (`modulo1` – `modulo9`)

Cada carpeta de módulo representa un dominio funcional del sistema. Su contenido es:

```
📂 moduloX/
├── 📄 moduloX.pgerd          → Diagrama relacional específico del módulo
├── 📄 sugerencias_moduloX.*  → Sugerencias de procedimientos, funciones y triggers para el módulo
├── 📄 informe_moduloX.*      → Informe de la logica y alcance del módulo
└── 📂 test/                  → (Solo en algunos módulos) Scripts de prueba
```

| Archivo / Carpeta | Descripción |
|---|---|
| `moduloX.pgerd` | Diagrama entidad-relación del módulo, abrir con pgAdmin |
| `sugerencias_moduloX` | Documento con recomendaciones de lógica de negocio: procedures, funciones y triggers sugeridos para ese módulo |
| `test/` | Carpeta de pruebas (no todos los módulos la tienen) |

> 💡 **Tip:** Para visualizar los archivos `.pgerd`, ábrelos desde **pgAdmin 4** → *Tools* → *Open ERD File*.

---

### 🛠️ Carpetas de Desarrollo

Estas carpetas contienen el trabajo desarrollado por el **equipo de desarrollo encargado**. Cada una sigue la misma estructura interna: subcarpetas organizadas por módulo con versionamiento de documentos.

```
📂 Procedimientos Almacenados/
│   └── 📂 moduloX/
│       ├── 📄 sp_moduloX_v1.sql
│       └── 📄 sp_moduloX_v2.sql   ← Usar siempre la versión más alta

📂 Scripts de Insercion - Constraints/
│   └── 📂 moduloX/
│       └── 📄 constraints_moduloX_vN.sql

📂 Trigger/
│   └── 📂 moduloX/
│       └── 📄 trigger_moduloX_vN.sql
```

| Carpeta | Contenido |
|---|---|
| **Procedimientos Almacenados** | Stored procedures organizados y versionados por módulo |
| **Scripts de Insercion - Constraints** | Scripts de inserción de datos iniciales y definición de constraints |
| **Trigger** | Triggers implementados en la base de datos, por módulo |

> ⚠️ **Versionamiento:** En cada subcarpeta puede haber múltiples versiones de un mismo archivo. **Siempre trabaja con el archivo de mayor numeración de versión** (ej: `v3` > `v2` > `v1`).

---

### 📌 Raíz del Proyecto

En la raíz encontrarás los recursos globales:

| Archivo | Descripción |
|---|---|
| `DiagramaRelacionalDB.pgerd` | 🗺️ **Diagrama relacional completo** de toda la base de datos. Es la vista macro de todas las tablas y sus relaciones |
| `Roles_y_Accesos.xlsx` | 👥 Documento de roles de usuario y permisos de acceso definidos en la DB |
| `Nomenclatura.xlsx` | 📐 Estándar de nomenclatura utilizado para nombrar tablas, columnas, procedures, triggers, etc. |
| `backup_vN.backup` | 💾 Respaldo de la base de datos. **Usar siempre el archivo con la versión más alta** |

---

### 📖 Diccionario de Datos (`dic_datos/`)

```
📂 dic_datos/
├── 📊 DocumentacionDB.pbix     → Archivo Power BI (documentación actualizada)
└── 📄 dic_datos.xlsx           → Diccionario de datos en Excel (hasta el último módulo documentado)
```

| Archivo | Descripción |
|---|---|
| `DocumentacionDB.pbix` | Fuente principal de documentación. Conectar con Power BI Desktop para editar |
| `dic_datos.xlsx` | Versión en Excel del diccionario de datos, útil para consulta rápida sin Power BI |

> 📌 La fuente de verdad y la versión más actualizada de la documentación siempre será el reporte de **Power BI** (ver sección siguiente).

---

## 📊 Documentación Interactiva — Power BI

La documentación de la base de datos está **automatizada y centralizada** en un reporte de Power BI de acceso público. Este reporte se mantiene actualizado y es la referencia oficial.

### 🔗 Enlace de acceso

> **[👉 Abrir Documentación en Power BI](https://app.powerbi.com/view?r=eyJrIjoiMWQ3Y2Y4ZWQtZmI5OC00NjcyLWJhM2UtN2I5YzRlMGRkMWExIiwidCI6IjRkOTYxOTFiLTAyMWQtNDBjMC1iYmYyLWUyNGJkMzc3NTliZSIsImMiOjR9)**

### 📑 Contenido del reporte

| Sección | Descripción |
|---|---|
| 📋 **Diccionario de Datos** | Documentación detallada de tablas y columnas, organizada por módulo |
| ⚡ **Triggers** | Documentación de todos los triggers implementados: qué hacen, en qué tabla y cuándo se disparan |
| 🗂️ **Catálogo de Objetos** | Inventario completo de vistas y procedimientos almacenados de la DB |
| 🏷️ **Enums** | Listado de tipos enumerados utilizados en la base de datos y sus valores posibles |

> 💡 No necesitas instalar nada. El reporte es de acceso web desde cualquier navegador.

---

## 🔒 Conexión a la Base de Datos — Tailscale

La base de datos **no está expuesta a internet directamente**. El acceso se realiza mediante **Tailscale**, una VPN segura y fácil de usar que permite conectarse como si estuvieras en la misma red local del servidor.

### ¿Cómo conectarse?

```
1. Instala Tailscale en tu equipo → https://tailscale.com/download
2. Solicita la invitación a la red (ver sección Contacto)
3. Acepta la invitación y conecta Tailscale
4. Usa el cliente de tu preferencia (pgAdmin, DBeaver, etc.) con las credenciales recibidas
```

> ✅ **Compatible con:** Windows, macOS, Linux, iOS y Android.

### Credenciales de acceso

Las credenciales de acceso a la base de datos **no se comparten en este repositorio** por seguridad. Solicítalas según tu rol (ver sección de Contacto).

---

## 📬 Contacto y Accesos

| Necesitas... | Contacta a... |
|---|---|
| 🔗 Invitación a la red **Tailscale** | **DBA del proyecto** — solicita la invitación para unirte a la red segura |
| 🔑 **Credenciales de acceso** a la DB (líderes de área) | **DBA del proyecto** — proporciona las credenciales según el rol asignado |
| ❓ Dudas sobre la estructura, diagramas o documentación | **DBA del proyecto** |

> 🙋 Si eres **líder de área**, comunícate directamente con el DBA para recibir tus credenciales de acceso con los permisos correspondientes a tu rol.
> 
> Si eres **desarrollador o miembro del equipo técnico**, solicita la invitación a Tailscale y el DBA te orientará con el acceso adecuado.

---

<div align="center">


*Ante cualquier duda sobre este repositorio, su contenido o la base de datos, contacta al DBA del proyecto.*

</div>
