import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio";
import { z } from "zod";
import pg from "pg";
import * as xlsx from "xlsx";
import "dotenv/config";

// Configurasion de base de datos
const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Se utiliza un 'Pool' en lugar de una conexión única (Client) porque permite manejar múltiples peticiones 
// concurrentes de la IA de forma eficiente, reutilizando conexiones inactivas y ahorrando memoria en el contenedor.
// Crear el servidor 
// interfas principal en el protocolo MCP. maneja la comunicasion entre el cliente y el servidor.

const server = new McpServer({
  name: "MCP Server demo",
  version: "1.0.0",
});

// Definir las herramientas 
// Cambia registerTool por tool
// Tool: Control de PostgreSQL 

server.tool(
    "Tool_PostgresSQL_Control", // Nombre 
    "Tool to control PostgreSQL database of RFC, Users, Generation of index and NewRFC", //Descripción
    {
        // Se usa z.enum para restringir estrictamente las acciones
        //  La IA solo puede elegir 'select' o 'insert'
        action: z.enum(["select", "insert"]).describe("Acción a realizar: select para visualizar, insert para almacenar"),
        query: z.string().describe("Consulta SQL estructurada y sanitizada"),
        // z.array(z.any()) permite pasar parámetros variables de forma segura para evitar inyección SQL.
        params: z.array(z.any()).optional().describe("Parámetros para evitar inyección SQL")
    },
    async ({ action, query, params }) => {
        try {
            // Se solicita un cliente libre del Pool de conexiones.
            const client = await pool.connect();
            // Se ejecuta la consulta
            //  Si la IA envía datos maliciosos, PostgreSQL los tratará como texto simple, no como código ejecutable.
            const result = await client.query(query, params || []);
            // Se libera la conexión evita cuello de botella 
            client.release();
            return {
                content: [{ type: "text", text: JSON.stringify(result.rows, null, 2) }]
            };
        } catch (error: any) {
            // Manejo de errores sin detener el servidor. La IA recibe el error y puede intentar corregir su consulta.
            return { content: [{ type: "text", text: `Error en BD: ${error.message}` }] };
        }
    }
);
// Conexion a SharePoint 
server.tool(
    "Tool_SherePoint",
    "Access SharePoint to search for and read documents, and to move them to different locations",
    {
        //Restricciones de la herramienta ( No debe de poder usar 'delete' ni 'write' )
        action: z.enum(["read", "move"]).describe("Acción a realizar: read para leer, move para mover documentos"),
        fileId: z.string().describe("ID o URL del archivo en SharePoint"),
        destinationFolder: z.string().optional().describe("ID de la carpeta destino si la acción es 'move'")
    },
    async ({ action, fileId, destinationFolder }) => {
        // Aquí se implementará Microsoft 
        return {
            content: [{ type: "text", text: `Acción ${action} ejecutada sobre el archivo ${fileId}.` }]
        };
    }
);

// control + k + u o c

// // TOOL 4: Extracción de Contactos (Regex)
// server.tool(
//     "Tool_Analyze_Contacts_RFC",
//     "Analiza el contenido de un RFC en Excel buscando nombres y correos, y los adjunta al directorio.",
//     {
//         filePath: z.string().describe("Ruta del archivo Excel a analizar")
//     },
//     async ({ filePath }) => {
//         // Este paso automatiza la lectura manual. Buscará patrones (ej. *@macropay.mx) y construirá un array de datos.
//         return {
//             content: [{ type: "text", text: `Análisis completado para ${filePath}.` }]
//         };
//     }
// );

// // TOOL 5: Creación de RFC (En espera)
// server.tool(
//     "Tool_Create_New_RFC",
//     "PENDIENTE: Crea un nuevo RFC estructurado o una tabla de Excel desde cero.",
//     {
//         rfcData: z.string().describe("Datos preliminares del RFC")
//     },
//     async ({ rfcData }) => {
//         // Bloque funcional preparado para escalar cuando definamos la estructura de salida.
//         return {
//             content: [{ type: "text", text: `Herramienta en pausa. Esperando definición de estructura por el usuario.` }]
//         };
//     }
// );

// // 5. ARRANQUE DEL SERVIDOR
// // Se inicializa el transporte de datos y se conecta el servidor para que la IA comience a escuchar comandos. 

const transport = new StdioServerTransport();
await server.connect(transport);
console.log("MCP Server conectado y listo para operar sobre StdIO.");
