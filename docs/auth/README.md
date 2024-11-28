Hybrid Session Management Flow:

    User Login
        Credentials are validated.
        Session token is generated and stored in:
            Cookie: Short-lived, HTTP-only, and secure cookie.
            UserSession Table (PostgreSQL): Persistent storage for long-term tracking.

    Session Validation
        Redis: First check for session validity. If found, respond quickly.
        Fallback to UserSession Table: If Redis doesn't have the session, check the UserSession table.

    Session Update
        Any updates (e.g., activity timestamp) are applied to Redis.
        Periodically sync Redis with the UserSession table for persistence.

    Logout/Session Revocation
        Delete session data from Redis and mark the session as invalid in the UserSession table.

    Cookie Expiry or Invalid Session
        Redirect the user to login if the cookie is expired or the session is invalid in both Redis and the database.

Redis vs. UserSession Table:

    Redis: Optimized for speed, ideal for frequently accessed session data.
    UserSession Table: Secure and persistent, suitable for auditing and fallback.
