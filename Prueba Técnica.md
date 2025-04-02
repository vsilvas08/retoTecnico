# Prueba Técnica - Desafío DevOps Por Victor Silva
## **Introducción**
El presente documento describe la solución propuesta para el desafío técnico. Se abordarán los requerimientos planteados en las secciones de Infraestructura como Código, Integración y Entrega Continua (CI/CD), y evaluación teórica de conocimientos técnicos. La solución está diseñada con un enfoque modular y bien documentado para garantizar su correcta implementación y mantenimiento en el ciclo de vida del software

-----
## **Infraestructura como Código (IaC)**
### Herramienta Seleccionada
Se utilizará **Terraform** como herramienta principal para la gestión de infraestructura debido a:

- Su compatibilidad con AWS y múltiples proveedores de nube, teniendo en cuenta que la nube a utilizar es AWS, considero que es la herramienta que en el momento esta mas adaptada con la declaración y uso de recursos de AWS.
- La facilidad de modularización y reutilización del código, en este punto lo que debemos de pensar es no solo en el árbol (el problema planteado) sino en el bosque, donde podemos crear módulos que mas adelante en cualquier otro proyecto los podamos instanciar y utilizar sin ningún problema. Adicional mas adelante puede ser una base para crear devops como servicio, donde podemos aislar esta capa lógica de componentes y enfocarnos en las necesidades del negocio con un servicio que se encargue de utilizar terraform y sus módulos de manera estándar.
- Su enfoque declarativo y control de cambios mediante estado remoto, cuando hacemos múltiples cambios en nuestras infraestructuras no hay mejor manera de manejarlos que desde los estados de terraform y si a esto le sumamos que podemos utilizar un bucket s3 como un backend propio por aplicativo, ahí tendríamos toda la historia de cada implementación.
- La capacidad de ser agnóstica a cualquier nube, en este punto podemos tener la ventaja de redesplegar la infraestructura en cualquier proveedor nube con pequeños cambios de nombres de recursos y su utilidad.
- Una desventaja inicial puede ser la necesidad de crear los módulos particulares para los recursos que se deben de ir realizando, pero a largo plazo esto nos apalancara la reutilización de código, estructura, estados de los recursos de cada aplicación.
### Diseño de la Solución

Se explicara la solución propuesta para cada punto y adicional se implementaran estos recursos en el repositorio <https://github.com/vsilvas08/retoTecnico> y utilizando como base el repositorio <https://github.com/vsilvas08/terraform_modules>.

Usaremos Github como gestor de repositorios de código y AzureDevops para el uso de los pipelines y librerías de recursos.

1. **VPC y Subredes Personalizadas**
   1. Se implementará una VPC personalizada con subredes públicas, privadas y aisladas para garantizar una infraestructura segura y escalable.
   1. Subredes Públicas: Estas subredes estarán expuestas a Internet y contendrán recursos que requieren acceso público, como balanceadores de carga (ALB) y NAT Gateways.
   1. Subredes Privadas: Estas subredes alojarán los servicios de ECS Fargate, asegurando que los contenedores no tengan exposición directa a Internet. Solo serán accesibles a través del balanceador de carga o mediante conexiones seguras desde una VPN o de reglas creadas a la medida para cada recurso que lo necesite.
   1. Subredes Aisladas: Reservadas para bases de datos y otros recursos internos que no necesitan acceso a Internet ni exposición pública, mejorando la seguridad y reduciendo la superficie de ataque.
   1. La distribución de CIDR y cantidad de subredes será parametrizable, permitiendo su ajuste según las necesidades del entorno.

1. **ECS Fargate y ECR**
   1. Creación de un cluster de ECS Fargate sin asignar IPs públicas.
   1. Registro de imágenes en ECR con políticas de acceso seguras, basada en los roles que creemos desde IAM para los usuarios pueden ser de conexión externa como los service connection de una aplicación como Azure Devops o el mismo github actions.
   1. Despliegue de dos aplicaciones en el cluster con las estrategas de Rolling Update y Blue Green Deployment. Donde aprovecharemos las ventajas de cada una para las dos aplicaciones, con el Rolling update podremos desplegar una nueva versión del aplicativo sin tener tiempos de inactividad, reemplazando los contenedores antiguos progresivamente y con Blue Green podemos ir liberando de manera controlada los componentes de un despliegue para ir probando las nuevas implementaciones todo antes de la transición a productivo.


1. **Exposición de Servicios**
   1. Configuración de un Application Load Balancer  para enrutar tráfico HTTPS (puerto 443) hacia los servicios en ECS Fargate.
   1. Se garantizará que la única forma de acceder a las aplicaciones será a través del ALB, evitando accesos directos desde subredes privadas.** 
   1. Motivo del Diseño:
      1. Seguridad: Al no exponer instancias de ECS directamente, se evita cualquier riesgo de acceso no autorizado a los contenedores.
      1. Escalabilidad: Un ALB permite distribuir la carga de tráfico de manera eficiente y soporta múltiples instancias de contenedores sin necesidad de configuraciones manuales adicionales.
      1. Gestión Centralizada: Facilita la implementación de políticas de seguridad como WAF, control de acceso por IP y certificados SSL/TLS.
   1. Implementación en Terraform:
      1. Creación del ALB y listener HTTPS (puerto 443) con certificado SSL.
      1. Definición de reglas de enrutamiento y target groups para distribuir el tráfico a los servicios de ECS.
      1. Configuración de grupos de seguridad para permitir únicamente tráfico desde el ALB hacia ECS Fargate.
      1. Bloqueo explícito de accesos desde subredes privadas, garantizando que los servicios solo puedan ser accedidos a través del Load Balancer.

1. **Alta Disponibilidad y Autoescalado**
   1. Configuración de autoescalado basado en métricas de CPU y tráfico.
   1. Definición de estrategias de tolerancia a fallos y recuperación automática.

1. **Seguridad y Control de Acceso**
   1. Configuración de **grupos de seguridad** para restringir acceso innecesario a los servicios, estos SG deben de ir desde los recursos específicos que necesiten acceso a otros recursos y no ser abiertos para cualquier acción.
   1. Uso de **AWS IAM** para gestionar permisos y accesos mínimos necesarios (principio de menor privilegio), donde empezaremos un proceso de deny all y solo abriremos los puertos y comunicaciones necesarias para la comunicación de la aplicación.
   1. Implementación de **listas de control de acceso (ACLs)** para reforzar la seguridad en las subredes, en las cuales podemos hacer focos de comunicación estrcuturada y controlada

1. **Gestión de Configuraciones y Parámetros**
   1. Uso de **AWS Parameter Store o AWS Secrets Manager** para almacenar credenciales y configuraciones sensibles así garantizamos que nadie las cambie en un entorno de desarrollo normal y adicional a que tengamos todo centralizado sin fugas de información.
   1. Manejo de configuraciones mediante **archivos de variables** en Terraform para facilitar la personalización de entornos, también tendremos la implementación de variables por ambiente y por aplicativo desde las library de Azure Devops.

1. **Monitoreo y Logging**
   1. Integración con **Amazon CloudWatch** para recopilar métricas del cluster y los servicios, especialmente para tener un primer control del comportmiento de la infraestructura y determinarlos en loggruops para exportarlos a aplicaciones que nos den el manejo integral de la observalidad, así como dynatrace o grafana donde tendremos el E2E de la solución con graficos y análisis de comportamientos en tiempo real.
   1. Implementación de **AWS CloudTrail** para auditar cambios en la infraestructura, este es un factor clave que nos entrega AWS para evitar cambios manuales o intervenciones de la infraestructura fuera de los controles y definiciones creadas desde terraform.
-----
## **Integración y Entrega Continua (CI/CD)**
### Herramienta Seleccionada
Se utilizará **Azure DevOps** para la automatización del pipeline, debido a:

- Su integración con repositorios de código y gestión de proyectos en la nube, allí vamos a tener toda la trazabilidad y el gobierno de la ejecución de los pipelines y las integraciones que se vayan realizando. AzureDevops nos ofrece una buena integración al modelo de historias de usuario asociadas a cada despliegue, gestión de tableros por equipos y sus avances y a nivel tecnológico de integración podemos acceder fácilmente a Github y AWS mediante una correcta configuración de los service connection.
- Contamos con muchas ayudas e integraciones para trabajar con pipelines como código en este caso con los YAML.
- Capacidad de manejar despliegues multi-ambiente y control de versiones, que lo manejaramos desde el uso de los parámetros y los environments, además de tener un solo pipeline pero utilizar multiples library para determinar el ambiente a desplegar y sus características particulares. 
### Descripción del Pipeline
1. **Estructura Multi-Ambiente y Multi-Región**
   1. Despliegue en tres ambientes: dev, stg y prod. Esto lo realizaremos teniendo 3 grupos de variables o Library y allí dejaremos las características particuales de cada uno de los ambientes con sus respectivos nombres (agregando -dev, -stg o -prod a cada recurso)
   1. Asignación de regiones: Ohio (dev), Virginia (stg) y Oregon (prod). Estas regiones van a ser una variable particular en cada grupo de variables o library por ambiente y esto también nos brindara la capacidad de no reutilizar y no tener que hacer un commit especifico para este cambio, sino de utilizar el mismo código fuente y cambiar las variables desde AzureDevops (componente de despliegue) de manera mas administrativa y estratégica.

      ![](Aspose.Words.7daeed9c-25c9-456d-8919-0e7606a7ef1f.001.png)

      ![](Aspose.Words.7daeed9c-25c9-456d-8919-0e7606a7ef1f.002.png)

      ![](Aspose.Words.7daeed9c-25c9-456d-8919-0e7606a7ef1f.003.png)

1. **Estrategias de Despliegue**
   1. **Rolling Update**: con esta estrategia pretendemos desplegar nuevas versiones sin tiempo de inactividad, es decir, poder desplegar componentes nuevos dentro del cluster ECS e ir levantando instancias nuevas progresivamente sin afectar los procesos que estén ya desplegados en las intancias mas viejas que se van a ir reemplazando progresivamente.
   1. **Blue-Green Deployment**: Es si no, la mas utilizada en el mundo de los despliegues, dado que nos da la capacidad de realizar pruebas en un entorno idéntico antes de realizar un cambio real a un ambiente productivo, con esta estrategia podemos estar tranquilos al momento de llevar nuestros cambios previamente probados.

 

1. **Pruebas y Validaciones**
   1. Implementación de pruebas automáticas de conectividad y disponibilidad post-despliegue.
   1. Se definirá un ambiente completo de pruebas automatizadas para cada despliegue, donde crearemos un pipeline de RM para cada ambiente y así podremos tener pruebas E2E de todo tipo para determinar si nuestra implementación esta apta para salir a producción o no.
   1. También tendremos pruebas de seguridad por medio de aplicaciones externas de análisis de código fuente y vulnerabilidades como SonarQube y Kiuwan

##
## **Prueba Teórica**
### 1\. Publicación de Aplicaciones en un Dominio con HTTPS (443)
**Solución 1: Nginx como Proxy Reverso**

- Configuración de un servidor Nginx para redirigir tráfico del dominio mipruebaFinaktiva.com.co al servidor LAN Esto básicamente es crear un puente entre las comunicaciones y poder tener una conexión directa y sin afectaciones a los usuarios.
- Definición de reglas de proxy\_pass para redirigir / al puerto 8080 y /ws al puerto 8443, garantizando de manera transparente el redireccionamiento al ws.

**Solución 2: AWS Application Load Balancer**

- Implementación de un ALB que distribuya tráfico basado en reglas de rutas, estas reglas deben quedar definidas con cada uno de los casos de uso posibles de la aplicación como el antes mencionado en el reto.
- Registro de instancias o targets con mapeo de puertos internos, utilizando los health checks que nos darán la visual de que puertos están fallando y como redirigir las peticiones a los saludables.
### 2\. Diagnóstico de Problema de Conectividad
1. **Falla en DNS**: Verificar la resolución del dominio con nslookup o dig. Validando la traza completa como empieza y si si esta llegando al destino deseado.
1. **Bloqueo por Firewall**: Comprobar reglas de seguridad en la red del cliente, para esto podemos apoyarnos en una herramienta como paloalto donde desglosemos las comunicaciones y los envios y recepciones de paquetes por todo el ambiente.
1. **Certificado SSL Expirado o Incorrecto**: Validar con openssl s\_client. Aunque suene muy basico, la mayoría de veces que un certificado es creado es olvidado y sin su renovación podemos ver estas problemáticas.
1. **Configuración Incorrecta en el Load Balancer**: llendonos a un ambiente mas de revisión interna tener que empezar a determinar que nos esta saliendo en logs y reglas de enrutamiento que tenemos.


   **2**
### 3\. Algoritmos de Balanceo de Carga

|**Algoritmo**|**Descripción**|**Casos de Uso**|
| :-: | :-: | :-: |
|**Round Robin**|Distribuye tráfico equitativamente entre servidores.|Aplicaciones de carga balanceada uniforme.|
|**Weighted Round Robin**|Prioriza servidores con mayor peso asignado.|Infraestructura con servidores de diferente capacidad.|
|**Least Connection**|Envía tráfico al servidor con menos conexiones activas.|Aplicaciones con cargas desiguales entre servidores.|
|**Source IP Hash**|Mantiene persistencia de sesión asignando clientes a un mismo servidor.|Aplicaciones que requieren afinidad de sesión.|
|**URI-based Routing**|Redirige tráfico basado en patrones de URL.|Aplicaciones con microservicios o APIs segmentadas.|

