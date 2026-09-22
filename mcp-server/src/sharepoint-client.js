// =====================================================
// SharePoint Client Module
// Supports both Mock (filesystem) and Real (Azure) modes
// =====================================================

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

/**
 * Cliente para interactuar con SharePoint
 * Modo Mock: guarda en filesystem
 * Modo Real: usa Microsoft Graph API + Azure Entra ID
 */
class SharePointClient {
    constructor(config = {}) {
        this.mockMode = config.mockMode || process.env.SHAREPOINT_MOCK_MODE === 'true';
        this.mockPath = config.mockPath || process.env.SHAREPOINT_MOCK_PATH || '/app/sharepoint_mock';

        // Configuración Real (Azure)
        this.tenantId = config.tenantId || process.env.AZURE_TENANT_ID;
        this.clientId = config.clientId || process.env.AZURE_CLIENT_ID;
        this.clientSecret = config.clientSecret || process.env.AZURE_CLIENT_SECRET;
        this.tenant = config.tenant || process.env.SHAREPOINT_TENANT;
        this.siteName = config.siteName || process.env.SHAREPOINT_SITE_NAME;

        // Token cache
        this.accessToken = null;
        this.tokenExpiresAt = null;
    }

    /**
     * Verificar modo de operación
     */
    isRealMode() {
        return !this.mockMode && this.tenantId && this.clientId && this.clientSecret;
    }

    /**
     * MODO MOCK: Crear directorio si no existe
     */
    async ensureMockDirectory() {
        if (!this.mockMode) return;
        try {
            await fs.mkdir(this.mockPath, { recursive: true });
        } catch (error) {
            console.error('Error creating mock directory:', error);
        }
    }

    /**
     * Autenticar con Azure (Modo Real)
     */
    async authenticate() {
        if (this.mockMode) return { success: true, mode: 'mock' };

        try {
            const tokenUrl =
                `https://login.microsoftonline.com/${this.tenantId}/oauth2/v2.0/token`;

            const response = await axios.post(tokenUrl, {
                grant_type: 'client_credentials',
                client_id: this.clientId,
                client_secret: this.clientSecret,
                scope: 'https://graph.microsoft.com/.default'
            });

            this.accessToken = response.data.access_token;
            this.tokenExpiresAt = Date.now() + (response.data.expires_in * 1000) - 60000;

            return { success: true, mode: 'azure' };
        } catch (error) {
            throw new Error(`SharePoint authentication failed: ${error.message}`);
        }
    }

    /**
     * Asegurar que el token está válido
     */
    async ensureAuthenticated() {
        if (this.mockMode) return;
        if (!this.accessToken || Date.now() >= this.tokenExpiresAt) {
            await this.authenticate();
        }
    }

    /**
     * Obtener headers para requests a Microsoft Graph
     */
    async getHeaders() {
        await this.ensureAuthenticated();
        return {
            'Authorization': `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json'
        };
    }

    /**
     * MOCK: Subir archivo a directorio mock
     */
    async uploadMarkdownFileMock(folderId, filename, content) {
        try {
            await this.ensureMockDirectory();

            const folderPath = path.join(this.mockPath, folderId || 'default');
            await fs.mkdir(folderPath, { recursive: true });

            const filePath = path.join(folderPath, filename);
            await fs.writeFile(filePath, content, 'utf-8');

            return {
                success: true,
                mode: 'mock',
                file_id: `mock-${Date.now()}`,
                file_url: `file://${filePath}`,
                size: content.length,
                created_at: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`Mock file upload failed: ${error.message}`);
        }
    }

    /**
     * REAL: Subir archivo a SharePoint vía Microsoft Graph
     */
    async uploadMarkdownFileReal(siteId, folderId, filename, content) {
        try {
            const headers = await this.getHeaders();
            const buffer = Buffer.from(content, 'utf-8');

            const response = await axios.put(
                `https://graph.microsoft.com/v1.0/sites/${siteId}/drive/items/${folderId}:/${filename}:/content`,
                buffer,
                {
                    headers: {
                        ...headers,
                        'Content-Type': 'text/markdown'
                    }
                }
            );

            return {
                success: true,
                mode: 'azure',
                file_id: response.data.id,
                file_url: response.data.webUrl,
                size: response.data.size,
                created_at: response.data.createdDateTime
            };
        } catch (error) {
            throw new Error(`SharePoint upload failed: ${error.response?.data?.error?.message || error.message}`);
        }
    }

    /**
     * Subir archivo - elige automáticamente mock o real
     */
    async uploadMarkdownFile(folderId, filename, content) {
        if (this.mockMode) {
            return await this.uploadMarkdownFileMock(folderId, filename, content);
        } else {
            return await this.uploadMarkdownFileReal(folderId, folderId, filename, content);
        }
    }

    /**
     * MOCK: Actualizar archivo
     */
    async updateFileMock(fileId, newContent) {
        try {
            // En mock, fileId es la ruta del archivo
            const filePath = fileId.replace('file://', '');
            await fs.writeFile(filePath, newContent, 'utf-8');

            return {
                success: true,
                mode: 'mock',
                updated_at: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`Mock file update failed: ${error.message}`);
        }
    }

    /**
     * REAL: Actualizar archivo
     */
    async updateFileReal(siteId, fileId, newContent) {
        try {
            const headers = await this.getHeaders();
            const buffer = Buffer.from(newContent, 'utf-8');

            await axios.put(
                `https://graph.microsoft.com/v1.0/sites/${siteId}/drive/items/${fileId}/content`,
                buffer,
                { headers: { ...headers, 'Content-Type': 'text/markdown' } }
            );

            return {
                success: true,
                mode: 'azure',
                updated_at: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`SharePoint update failed: ${error.message}`);
        }
    }

    /**
     * Actualizar archivo - elige automáticamente mock o real
     */
    async updateFile(fileId, newContent) {
        if (this.mockMode) {
            return await this.updateFileMock(fileId, newContent);
        } else {
            return await this.updateFileReal(fileId, fileId, newContent);
        }
    }

    /**
     * MOCK: Mover archivo
     */
    async moveFileMock(fileId, targetFolderId, newName) {
        try {
            const oldPath = fileId.replace('file://', '');
            const targetPath = path.join(
                this.mockPath,
                targetFolderId,
                newName || path.basename(oldPath)
            );

            await fs.mkdir(path.dirname(targetPath), { recursive: true });
            await fs.rename(oldPath, targetPath);

            return {
                success: true,
                mode: 'mock',
                new_path: `file://${targetPath}`,
                moved_at: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`Mock file move failed: ${error.message}`);
        }
    }

    /**
     * REAL: Mover archivo
     */
    async moveFileReal(siteId, fileId, targetFolderId, newName) {
        try {
            const headers = await this.getHeaders();

            const patchData = {
                parentReference: { id: targetFolderId }
            };

            if (newName) {
                patchData.name = newName;
            }

            await axios.patch(
                `https://graph.microsoft.com/v1.0/sites/${siteId}/drive/items/${fileId}`,
                patchData,
                { headers }
            );

            return {
                success: true,
                mode: 'azure',
                moved_at: new Date().toISOString()
            };
        } catch (error) {
            throw new Error(`SharePoint move failed: ${error.message}`);
        }
    }

    /**
     * Mover archivo - elige automáticamente mock o real
     */
    async moveFile(fileId, targetFolderId, newName) {
        if (this.mockMode) {
            return await this.moveFileMock(fileId, targetFolderId, newName);
        } else {
            return await this.moveFileReal(fileId, fileId, targetFolderId, newName);
        }
    }

    /**
     * MOCK: Obtener metadata del archivo
     */
    async getFileMetadataMock(fileId) {
        try {
            const filePath = fileId.replace('file://', '');
            const stats = await fs.stat(filePath);

            return {
                success: true,
                mode: 'mock',
                id: fileId,
                name: path.basename(filePath),
                size: stats.size,
                created_at: stats.birthtime,
                modified_at: stats.mtime,
                url: fileId
            };
        } catch (error) {
            throw new Error(`Mock metadata retrieval failed: ${error.message}`);
        }
    }

    /**
     * REAL: Obtener metadata del archivo
     */
    async getFileMetadataReal(siteId, fileId) {
        try {
            const headers = await this.getHeaders();

            const response = await axios.get(
                `https://graph.microsoft.com/v1.0/sites/${siteId}/drive/items/${fileId}`,
                { headers }
            );

            return {
                success: true,
                mode: 'azure',
                id: response.data.id,
                name: response.data.name,
                size: response.data.size,
                created_at: response.data.createdDateTime,
                modified_at: response.data.lastModifiedDateTime,
                url: response.data.webUrl
            };
        } catch (error) {
            throw new Error(`SharePoint metadata retrieval failed: ${error.message}`);
        }
    }

    /**
     * Obtener metadata - elige automáticamente mock o real
     */
    async getFileMetadata(fileId) {
        if (this.mockMode) {
            return await this.getFileMetadataMock(fileId);
        } else {
            return await this.getFileMetadataReal(fileId, fileId);
        }
    }
}

module.exports = SharePointClient;
