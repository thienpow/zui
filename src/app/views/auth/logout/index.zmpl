<div id="auth-container" class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            <div class="logo">
                <svg class="logo-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                </svg>
                <span class="logo-text">zUI Portal</span>
            </div>

            <p class="subtitle">Sign out from the app?</p>
        </div>
        <!--  -->

        <form class="auth-form"
            hx-post="/auth/logout"
            hx-trigger="submit"
            hx-target="#error-message"
            hx-swap="innerHTML"
            hx-indicator="#loading">

            <div id="loading" class="htmx-indicator">
                Loading...
            </div>

            <button type="submit" class="button" aria-label="Yes">
                <span>Sign Out</span>
                <svg class="button-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 5l7 7m0 0l-7 7m7-7H3"/>
                </svg>
            </button>
        </form>
        <div class="auth-footer">
            <p><a href="/admin/dashboard">No, back to Dashboard</a></p>
        </div>

    </div>
</div>
