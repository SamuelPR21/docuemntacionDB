# 📦 Sistema de Gestión de Plataforma (SGP) - Base de Datos Relacional

## 📖 Descripción General

Este repositorio contiene el diseño, modelado, documentación, scripts y artefactos relacionados con la base de datos relacional del proyecto **SGP** desarrollada en PostgreSQL.

La arquitectura de la base de datos fue diseñada de manera modular, permitiendo una separación clara de responsabilidades por dominio funcional del sistema.

---

# 🚀 Tecnologías Utilizadas

| Tecnología | Versión |
|---|---|
| PostgreSQL | 18 |
| pgAdmin | 4 |
| Power BI | Automatización de documentación |
| Tailscale | Conectividad remota segura |
| PowerDesigner / pgModeler (.pgerd) | Diagramación relacional |

---

# 🧠 Arquitectura General del Proyecto

La base de datos está organizada por módulos independientes.

Cada módulo contiene:

- Modelo relacional correspondiente
- Scripts sugeridos
- Funciones
- Triggers
- Procedimientos almacenados
- Casos de prueba (en algunos módulos)

---

# 📂 Estructura del Repositorio

```bash
📦 ProyectoDB
│
├── modulo1/
├── modulo2/
├── modulo3/
├── modulo4/
├── modulo5/
├── modulo6/
├── modulo7/
├── modulo8/
├── modulo9/
│
├── Procedimientos Almacenados/
├── Scripts de Insercion - Constraints y Trigger/
├── dic_datos/
│
├── Backup_v1.backup
├── Backup_v2.backup
├── Backup_vN.backup
│
├── DiagramaRelacionalDB.pgerd
│
├── Roles_y_Accesos.xlsx
├── Nomenclatura.xlsx
│
└── README.md
