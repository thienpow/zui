<div class="auth-container">
    <div class="auth-box">
        <div id="error-message" class="error-message"></div>
        <div class="auth-header">
            <div class="logo">
                <svg class="logo-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
                </svg>
                <span class="logo-text">zUI Portal</span>
            </div>
            <h1>To the future</h1>
            <p class="subtitle">Please enter your credentials to sign in</p>
        </div>
        <!--  -->
        <form class="auth-form"
            hx-post="/auth/verify"
            hx-trigger="submit"
            hx-target="#error-message"
            hx-swap="innerHTML"
            hx-indicator="#loading">

            <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2z"/>
                        <path d="M2 8l10 5 10-5"/>
                    </svg>
                    <input type="email" id="email" name="email" placeholder="Enter your email" autocomplete="email" required>
                </div>
            </div>

            <div class="form-group">
                <div class="input-wrapper">
                    <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                        <path d="M7 11V7a5 5 0 0110 0v4"/>
                    </svg>
                    <input type="password" id="password" name="password" placeholder="Enter your password" autocomplete="current-password" required>
                </div>
            </div>

            <div id="loading" class="htmx-indicator">
                Loading...
            </div>

            <div class="form-group">
                <label class="checkbox-container">
                    <input type="checkbox" id="remember" name="remember">
                    <span class="checkmark"></span>
                    <span>Remember me</span>
                </label>
            </div>

            <button type="submit" class="auth-button" aria-label="Sign In">
                <span>Sign In</span>
                <svg class="button-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14 5l7 7m0 0l-7 7m7-7H3"/>
                </svg>
            </button>
        </form>

        <div class="auth-footer">
            <p>Don't have an account? <a href="/auth/signup"
               hx-boost="true"
               hx-target=".auth-container"
               hx-swap="innerHTML">Sign up</a></p>
        </div>
    </div>
</div>

@partial libs/styles/auth

<script>
    document.querySelector('.auth-form').addEventListener('submit', (event) => {
        const errorMessageContainer = document.querySelector('#error-message');
        errorMessageContainer.innerHTML = "";
    });

    document.body.addEventListener('htmx:responseError', (event) => {
        const { xhr } = event.detail;
        if (xhr.status === 401) {
            const errorMessageContainer = document.querySelector('#error-message');
            errorMessageContainer.innerHTML = "Invalid login credentials. Please try again.";
        }
    });

    document.body.addEventListener('htmx:afterRequest', (event) => {
        const { xhr } = event.detail;
        if (xhr.responseText.trim() === "success") {
            window.location.href = "/admin/dashboard";
        }
    });
</script>
