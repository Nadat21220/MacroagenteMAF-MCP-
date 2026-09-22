// =====================================================
// Auth Middleware for Document Operations
// Validates headers and user authentication
// =====================================================

/**
 * Middleware para validar autenticación en endpoints de documentos
 * Requiere:
 * - Header: X-Requested-By (email válido) O
 * - Body: requested_by (email válido)
 */
const authMiddleware = (req, res, next) => {
    // Obtener requested_by del header o body
    const requestedBy =
        req.headers['x-requested-by'] ||
        req.body?.requested_by ||
        req.query?.requested_by;

    // Validar que existe
    if (!requestedBy) {
        return res.status(400).json({
            success: false,
            error: 'Missing authentication: X-Requested-By header or requested_by field required'
        });
    }

    // Validar formato de email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(requestedBy)) {
        return res.status(400).json({
            success: false,
            error: `Invalid email format: ${requestedBy}`
        });
    }

    // Agregar al objeto request para usar en handlers
    req.requestedBy = requestedBy;

    // Continuar
    next();
};

module.exports = authMiddleware;
