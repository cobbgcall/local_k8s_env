# Ambiente Local de Kubernetes basado en Podman y Kind

# Reseña

Kubernetes es una plataforma de código abierto que automatiza el despliegue, la administración y el escalado de aplicaciones en contenedores. Permite organizar y controlar múltiples contenedores en diferentes servidores, facilitando la operación de servicios distribuidos.

Las aplicaciones incluidas en este repositorio tienen como objetivo establecer una base para realizar respaldos del cluster (Velero), contar con un registro privado de contenedores (Harbor), monitorear el cluster y las aplicaciones desplegadas en él,(Prometheus, Jaeger y Grafana) asi como de disponer de una herramienta para CI/CD. En cada carpeta encontrarás los scripts y recursos necesarios para instalar y configurar cada una de estas soluciones.

Las aplicaciones que se despliegan o instalan en este repositorio tienen el objetivo de establecer una base para realizar backups del cluster, contar con un registro privado de contenedores, monitorear el cluster y disponer de una herramienta para CI/CD. En cada carpeta se entregarán los scripts y recursos necesarios para estas instalaciones.

**¿Qué son Podman y Kind?**  
Podman es una herramienta para gestionar contenedores de manera similar a Docker, pero sin necesidad de un demonio central y con mayor seguridad. Kind (Kubernetes IN Docker) permite crear clusters de Kubernetes locales utilizando contenedores, ideal para pruebas y desarrollo.

## Prerrequisitos

Estos ejemplos han sido desarrollados y probados con las siguientes versiones de herramientas:

- **Podman**: 5.6.1
- **Kind**: 0.3.0

Asegúrate de tener instaladas estas versiones (o superiores) para evitar incompatibilidades durante la ejecución de los ejemplos.
