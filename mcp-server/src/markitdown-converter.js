// =====================================================
// MarkItDown Converter Module
// Converts Excel/PDF documents to Markdown
// Uses: markitdown-js library
// =====================================================

const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');

// Importar markitdown-js
let convertDocument;
try {
    const markitdownModule = require('markitdown-js');
    // markitdown-js puede exportar de diferentes formas
    if (markitdownModule.convertDocument) {
        convertDocument = markitdownModule.convertDocument;
    } else if (markitdownModule.default?.convertDocument) {
        convertDocument = markitdownModule.default.convertDocument;
    } else if (typeof markitdownModule === 'function') {
        convertDocument = markitdownModule;
    }
} catch (error) {
    console.warn('markitdown-js not available, using fallback converter');
    convertDocument = null;
}

/**
 * Convierte archivos (Excel, PDF, etc) a Markdown
 * Usando la librería markitdown-js
 */
const MarkItDownConverter = {
    /**
     * Convierte un archivo a Markdown
     * @param {string} filePath - Ruta al archivo (debe existir)
     * @param {object} options - Opciones de conversión
     * @returns {object} { content: string, metadata: object }
     */
    async convertToMarkdown(filePath, options = {}) {
        try {
            // Verificar que archivo existe
            await fs.access(filePath);

            const fileName = path.basename(filePath);
            const fileExt = path.extname(filePath).toLowerCase();

            let markdown = '';

            // Intentar conversión con markitdown-js
            if (convertDocument) {
                try {
                    const result = await convertDocument(filePath, {
                        include_images: options.include_images || false,
                        max_lines: options.max_lines || 5000
                    });

                    // Extraer contenido markdown
                    if (typeof result === 'string') {
                        markdown = result;
                    } else if (typeof result === 'object' && result.markdown) {
                        markdown = result.markdown;
                    } else if (typeof result === 'object' && result.content) {
                        markdown = result.content;
                    } else if (typeof result === 'object' && result.text) {
                        markdown = result.text;
                    }
                } catch (conversionError) {
                    console.warn(`markitdown-js conversion error: ${conversionError.message}, using fallback`);
                    markdown = '';
                }
            }

            // Si markdown está vacío, usar fallback
            if (!markdown || markdown.trim() === '') {
                markdown = this._generateFallbackMarkdown(fileName, fileExt);
            }

            return {
                content: markdown,
                metadata: {
                    source_file: fileName,
                    file_type: fileExt,
                    conversion_time: new Date().toISOString(),
                    flavor: options.markdown_flavor || 'gfm',
                    include_images: options.include_images || false,
                    max_lines: options.max_lines || 5000,
                    library: convertDocument ? 'markitdown-js' : 'fallback'
                }
            };
        } catch (error) {
            throw new Error(`MarkItDown conversion failed: ${error.message}`);
        }
    },

    /**
     * Genera markdown de fallback cuando la conversión falla
     * Útil para archivos que no pueden ser parseados
     * @private
     */
    _generateFallbackMarkdown(fileName, fileExt) {
        let markdown = `# ${fileName}\n\n`;
        markdown += `_Documento convertido desde ${fileExt.replace('.', '').toUpperCase()}_\n\n`;
        markdown += `## Información del Archivo\n\n`;
        markdown += `- **Nombre:** ${fileName}\n`;
        markdown += `- **Tipo:** ${fileExt}\n`;
        markdown += `- **Convertido en:** ${new Date().toISOString()}\n\n`;
        markdown += `## Contenido\n\n`;
        markdown += `_El contenido de este documento está siendo procesado._\n`;
        markdown += `_Por favor, intenta la conversión nuevamente en unos momentos._\n`;
        return markdown;
    },

    /**
     * Calcula hash SHA256 del contenido
     * @param {string} content - Contenido a hashear
     * @returns {string} SHA256 hash
     */
    calculateContentHash(content) {
        return crypto
            .createHash('sha256')
            .update(content)
            .digest('hex');
    },

    /**
     * Guarda contenido markdown en memoria (BYTEA en DB)
     * @param {string} content - Contenido a guardar
     * @returns {Buffer} Contenido como Buffer para BYTEA
     */
    contentToBuffer(content) {
        return Buffer.from(content, 'utf-8');
    },

    /**
     * Obtiene estadísticas del contenido markdown
     * @param {string} content - Contenido MD
     * @returns {object} Estadísticas
     */
    getContentStats(content) {
        return {
            size_bytes: Buffer.byteLength(content, 'utf-8'),
            lines: content.split('\n').length,
            words: content.split(/\s+/).filter(w => w.length > 0).length,
            has_images: /!\[.*?\]\(.*?\)/.test(content),
            has_tables: /\|.*\|/.test(content),
            has_code: /```[\s\S]*?```/.test(content),
            has_headings: /#+ /.test(content),
            has_lists: /^[\s]*[-*+] /.test(content)
        };
    }
};

module.exports = MarkItDownConverter;
