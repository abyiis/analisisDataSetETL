# TADB 202610 — Examen 01
## Análisis de Viajes de Buses Escolares Eléctricos

**Universidad Pontificia Bolivariana**  
Curso: Tópicos Avanzados de Base de Datos — NRC 000475676 / 26025  
Período: 202610 | Valor: 20%

---

## Integrantes

| Nombre Completo | ID SIGAA | DBMS Asignado |
|-----------------|----------|---------------|
| [Juan david parra sierra] | [000475676] | PostgreSQL (Supabase) |

---

## Descripción del Proyecto

El Distrito de Ciencia, Tecnología e Innovación de Medellín evalúa la conversión de buses escolares de combustible a eléctricos. Este proyecto implementa una base de datos relacional normalizada (3NF) para analizar el comportamiento del **Estado de Carga (SoC)** de la batería en función de variables como distancia recorrida, cantidad de pasajeros y velocidad promedio.

Los datos corresponden a **2.280 registros sintéticos** de viajes generados para el periodo 2025-01-14 al 2025-06-30.

---

## Infraestructura Utilizada

| Componente | Detalle |
|------------|---------|
| Motor de BD | PostgreSQL (vía Supabase — plan gratuito) |
| IDE | JetBrains DataGrip |
| Proveedor nube | Supabase (supabase.com) |
| Puerto TCP | 5432 con SSL obligatorio (modo require) |
| Conexión | Cifrada TLS — cumple requisito de seguridad |

---

## Modelo de Datos

El modelo implementa normalización **3NF** con las siguientes tablas:

### Tablas Maestras
| Tabla | Descripción |
|-------|-------------|
| `zonas` | Zonas geográficas de las rutas |
| `conductores` | Maestro de conductores |
| `buses` | Maestro de buses con año de fabricación |
| `rutas` | Rutas con zona y distancia en km |

### Tabla de Hechos
| Tabla | Descripción |
|-------|-------------|
| `viajes` | Registro de cada viaje (2.280 filas) con SoC inicial, final y consumido |

### Tablas de Totalización
| Tabla | Descripción |
|-------|-------------|
| `estadisticas_conductor` | Totales por conductor y mes |
| `estadisticas_bus` | Totales por bus y mes |

### Vistas
| Vista | Descripción |
|-------|-------------|
| `v_detalle_viajes` | Join completo de todas las tablas |
| `v_consumo_por_dia_semana` | Consumo de SoC agrupado por día |
| `v_consumo_por_turno` | Consumo de SoC por turno AM/PM |

---

## Consultas de Exploración

| # | Consulta | Pregunta que responde |
|---|----------|-----------------------|
| 1 | Distancia vs. consumo de batería | ¿A mayor distancia, mayor consumo? |
| 2 | Pasajeros vs. consumo de batería | ¿A más pasajeros, mayor consumo? |
| 3 | Velocidad vs. consumo de batería | ¿La velocidad óptima tiene menor consumo? |

---

## Procedimientos Almacenados

| Procedimiento | Descripción |
|---------------|-------------|
| `p_calcula_estadisticas_conductor()` | Recalcula totalizaciones por conductor y mes |
| `p_calcula_estadisticas_bus()` | Recalcula totalizaciones por bus y mes |

Ambos procedimientos realizan `TRUNCATE` de la tabla destino antes de insertar, garantizando consistencia en cada ejecución.

---

## Seguridad

Se implementó un usuario de aplicación con **privilegios mínimos**:
```sql
CREATE USER usr_buses_app WITH PASSWORD 'BusesApp2026*';
```

| Privilegio | Tablas de negocio | Totalizaciones | Procedimientos |
|------------|:-----------------:|:--------------:|:--------------:|
| SELECT | ✅ | ✅ | — |
| INSERT / UPDATE / DELETE | ✅ | ❌ | — |
| EXECUTE | — | — | ✅ |
| CREATE / DROP | ❌ | ❌ | ❌ |

---

*Todos los datos utilizados son sintéticos y no representan conductores, buses ni rutas reales.*
