pub const SecurityError = error{
    InvalidInput,
    InvalidCredentials,
    SessionExpired,
    InvalidSession,
    RateLimitExceeded,
    InvalidToken,
    UnauthorizedAccess,
    ConfigurationError,
    StorageError,
    DatabaseError,
    TokenGenerationFailed,
    SessionCreationFailed,
    InvalidRefreshToken,
    UserNotFound,
    AccountLocked,
    AccountInactive,
    InvalidCSRFToken,
    SessionBindingMismatch,
    ValidationError,
    MetadataValidationFailed,
    InternalError,
    PasswordMismatch,
    WeakPassword,
};
