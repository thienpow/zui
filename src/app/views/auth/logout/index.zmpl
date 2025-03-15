<section id="auth-container" class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            @partial libs/components/brand
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

            @partial libs/components/btn_submit("Sign Out")
        </form>
        <div class="auth-footer">
            <p><a href="/admin/dashboard">No, back to Dashboard</a></p>
        </div>

    </div>
</section>
